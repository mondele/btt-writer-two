unit AppSettings;

{$mode objfpc}{$H+}

interface

uses
  Forms;

type
  TAppTheme = (atLight, atDark, atSystem);

procedure InitializeAppSettings;
function GetAppTheme: TAppTheme;
function GetEffectiveTheme: TAppTheme;
function DetectSystemTheme: TAppTheme;
procedure SetAppTheme(ATheme: TAppTheme; Persist: Boolean = True);
function ThemeToID(ATheme: TAppTheme): string;
function ThemeFromID(const S: string): TAppTheme;

{ General settings }
function GetGatewayLanguageMode: Boolean;
procedure SetGatewayLanguageMode(AValue: Boolean);
function GetBlindEditMode: Boolean;
procedure SetBlindEditMode(AValue: Boolean);
function GetBackupLocation: string;
procedure SetBackupLocation(const AValue: string);
function GetInterfaceLanguage: string;
procedure SetInterfaceLanguage(const AValue: string);

{ Server settings }
function GetServerSuite: string;
procedure SetServerSuite(const AValue: string);
function GetDataServer: string;
procedure SetDataServer(const AValue: string);
function GetMediaServer: string;
procedure SetMediaServer(const AValue: string);
function GetReaderServer: string;
procedure SetReaderServer(const AValue: string);
function GetCreateAccountURL: string;
procedure SetCreateAccountURL(const AValue: string);
function GetLanguagesURL: string;
procedure SetLanguagesURL(const AValue: string);
function GetIndexSQLiteURL: string;
procedure SetIndexSQLiteURL(const AValue: string);
function GetTranslationManualURL: string;
procedure SetTranslationManualURL(const AValue: string);

{ Developer settings }
function GetDeveloperTools: Boolean;
procedure SetDeveloperTools(AValue: Boolean);

{ Backup }
function GetDefaultBackupLocation: string;
function GetEffectiveBackupLocation: string;

{ Computed helpers }
function GetEffectiveDataServer: string;
function GetEffectiveCreateAccountURL: string;
procedure ApplyServerSuiteDefaults(const Suite: string);

{ Suite default URL helpers }
procedure GetSuiteDefaults(const Suite: string;
  out ADataServer, AMediaServer, AReaderServer, ACreateAccountURL,
  ALanguagesURL, AIndexSQLiteURL, ATranslationManualURL: string);

implementation

uses
  SysUtils, Classes, fpjson, jsonparser, Process, DataPaths;

const
  { WACS defaults }
  WACS_DATA_SERVER = 'https://content.bibletranslationtools.org';
  WACS_MEDIA_SERVER = 'https://api.bibletranslationtools.org';
  WACS_READER_SERVER = 'https://read.bibleineverylanguage.org';
  WACS_LANGUAGES_URL = 'https://langnames.bibleineverylanguage.org/langnames.json';
  WACS_INDEX_SQLITE_URL = 'https://writer-resources.bibletranslationtools.org/index.sqlite';
  WACS_TRANSLATION_MANUAL_URL = 'https://read.bibleineverylanguage.org/WA-Catalog/en_tm';

  { DCS defaults }
  DCS_DATA_SERVER = 'https://git.door43.org';
  DCS_MEDIA_SERVER = 'https://api.unfoldingword.org';
  DCS_READER_SERVER = 'https://door43.org/u';
  DCS_LANGUAGES_URL = 'https://td.unfoldingword.org/exports/langnames.json';
  DCS_INDEX_SQLITE_URL = 'https://writer-resources.bibletranslationtools.org/index.sqlite';
  DCS_TRANSLATION_MANUAL_URL = 'https://read.bibleineverylanguage.org/WA-Catalog/en_tm';

var
  FTheme: TAppTheme = atSystem;
  FInterfaceLanguage: string = 'en';
  FGatewayLanguageMode: Boolean = False;
  FBlindEditMode: Boolean = True;
  FBackupLocation: string = '';
  FServerSuite: string = 'wacs';
  FDataServer: string = '';
  FMediaServer: string = '';
  FReaderServer: string = '';
  FCreateAccountURL: string = '';
  FLanguagesURL: string = '';
  FIndexSQLiteURL: string = '';
  FTranslationManualURL: string = '';
  FDeveloperTools: Boolean = False;
  FTermsAccepted: Boolean = False;
  FLoaded: Boolean = False;

function SettingsPath: string;
begin
  Result := IncludeTrailingPathDelimiter(GetDataPath) + 'settings.json';
end;

function ThemeToID(ATheme: TAppTheme): string;
begin
  case ATheme of
    atDark: Result := 'dark';
    atSystem: Result := 'system';
  else
    Result := 'light';
  end;
end;

function ThemeFromID(const S: string): TAppTheme;
var
  T: string;
begin
  T := LowerCase(Trim(S));
  if T = 'dark' then
    Result := atDark
  else if T = 'system' then
    Result := atSystem
  else
    Result := atLight;
end;

function DetectSystemTheme: TAppTheme;
var
  P: TProcess;
  OutS: TStringStream;
  Output: string;
begin
  Result := atLight;
  P := TProcess.Create(nil);
  OutS := TStringStream.Create('');
  try
    P.Options := [poUsePipes, poWaitOnExit, poStderrToOutPut];
    {$IFDEF LINUX}
    { GNOME/GTK: check color-scheme preference }
    P.Executable := 'gsettings';
    P.Parameters.Add('get');
    P.Parameters.Add('org.gnome.desktop.interface');
    P.Parameters.Add('color-scheme');
    {$ENDIF}
    {$IFDEF DARWIN}
    { macOS: AppleInterfaceStyle is "Dark" when dark mode is on }
    P.Executable := 'defaults';
    P.Parameters.Add('read');
    P.Parameters.Add('-g');
    P.Parameters.Add('AppleInterfaceStyle');
    {$ENDIF}
    {$IFDEF WINDOWS}
    { Windows: registry query for AppsUseLightTheme (0=dark, 1=light) }
    P.Executable := 'reg';
    P.Parameters.Add('query');
    P.Parameters.Add('HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize');
    P.Parameters.Add('/v');
    P.Parameters.Add('AppsUseLightTheme');
    {$ENDIF}
    try
      P.Execute;
      OutS.CopyFrom(P.Output, 0);
      Output := LowerCase(Trim(OutS.DataString));
      {$IFDEF LINUX}
      if Pos('prefer-dark', Output) > 0 then
        Result := atDark;
      {$ENDIF}
      {$IFDEF DARWIN}
      if Pos('dark', Output) > 0 then
        Result := atDark;
      {$ENDIF}
      {$IFDEF WINDOWS}
      { Output contains "0x0" for dark, "0x1" for light }
      if Pos('0x0', Output) > 0 then
        Result := atDark;
      {$ENDIF}
    except
      { Command not available or failed — default to light }
    end;
  finally
    OutS.Free;
    P.Free;
  end;
end;

function GetEffectiveTheme: TAppTheme;
begin
  Result := GetAppTheme;
  if Result = atSystem then
    Result := DetectSystemTheme;
end;

procedure SaveSettings;
var
  Obj: TJSONObject;
  SL: TStringList;
  Path: string;
begin
  Path := SettingsPath;
  ForceDirectories(ExtractFileDir(Path));
  Obj := TJSONObject.Create;
  try
    Obj.Add('theme', ThemeToID(FTheme));
    Obj.Add('interface_language', FInterfaceLanguage);
    Obj.Add('gateway_language_mode', FGatewayLanguageMode);
    Obj.Add('blind_edit_mode', FBlindEditMode);
    Obj.Add('backup_location', FBackupLocation);
    Obj.Add('server_suite', FServerSuite);
    Obj.Add('data_server', FDataServer);
    Obj.Add('media_server', FMediaServer);
    Obj.Add('reader_server', FReaderServer);
    Obj.Add('create_account_url', FCreateAccountURL);
    Obj.Add('languages_url', FLanguagesURL);
    Obj.Add('index_sqlite_url', FIndexSQLiteURL);
    Obj.Add('translation_manual_url', FTranslationManualURL);
    Obj.Add('developer_tools', FDeveloperTools);
  Obj.Add('terms_accepted', FTermsAccepted);
    SL := TStringList.Create;
    try
      SL.Text := Obj.FormatJSON;
      SL.SaveToFile(Path);
    finally
      SL.Free;
    end;
  finally
    Obj.Free;
  end;
end;

procedure LoadSettings;
var
  Path: string;
  SL: TStringList;
  Data: TJSONData;
  Obj: TJSONObject;
begin
  if FLoaded then
    Exit;
  FLoaded := True;
  FTheme := atSystem;
  FInterfaceLanguage := 'en';
  FGatewayLanguageMode := False;
  FBlindEditMode := True;
  FBackupLocation := '';
  FServerSuite := 'wacs';
  FDataServer := '';
  FMediaServer := '';
  FReaderServer := '';
  FCreateAccountURL := '';
  FLanguagesURL := '';
  FIndexSQLiteURL := '';
  FTranslationManualURL := '';
  FDeveloperTools := False;
  Path := SettingsPath;
  if not FileExists(Path) then
    Exit;

  SL := TStringList.Create;
  try
    SL.LoadFromFile(Path);
    Data := nil;
    try
      Data := GetJSON(SL.Text);
      if Data is TJSONObject then
      begin
        Obj := TJSONObject(Data);
        FTheme := ThemeFromID(Obj.Get('theme', 'system'));
        FInterfaceLanguage := Obj.Get('interface_language', 'en');
        FGatewayLanguageMode := Obj.Get('gateway_language_mode', False);
        FBlindEditMode := Obj.Get('blind_edit_mode', False);
        FBackupLocation := Obj.Get('backup_location', '');
        FServerSuite := Obj.Get('server_suite', 'wacs');
        FDataServer := Obj.Get('data_server', '');
        FMediaServer := Obj.Get('media_server', '');
        FReaderServer := Obj.Get('reader_server', '');
        FCreateAccountURL := Obj.Get('create_account_url', '');
        FLanguagesURL := Obj.Get('languages_url', '');
        FIndexSQLiteURL := Obj.Get('index_sqlite_url', '');
        FTranslationManualURL := Obj.Get('translation_manual_url', '');
        FDeveloperTools := Obj.Get('developer_tools', False);
  FTermsAccepted := Obj.Get('terms_accepted', False);
      end;
    except
      { Corrupt settings file — silently fall back to defaults }
    end;
    Data.Free;
  finally
    SL.Free;
  end;
end;

procedure InitializeAppSettings;
begin
  LoadSettings;
end;

{ Theme }

function GetAppTheme: TAppTheme;
begin
  LoadSettings;
  Result := FTheme;
end;

procedure SetAppTheme(ATheme: TAppTheme; Persist: Boolean = True);
begin
  LoadSettings;
  FTheme := ATheme;
  if Persist then
    SaveSettings;
end;

{ General settings }

function GetInterfaceLanguage: string;
begin
  LoadSettings;
  Result := FInterfaceLanguage;
end;

procedure SetInterfaceLanguage(const AValue: string);
begin
  LoadSettings;
  FInterfaceLanguage := AValue;
  SaveSettings;
end;

function GetGatewayLanguageMode: Boolean;
begin
  LoadSettings;
  Result := FGatewayLanguageMode;
end;

procedure SetGatewayLanguageMode(AValue: Boolean);
begin
  LoadSettings;
  FGatewayLanguageMode := AValue;
  SaveSettings;
end;

function GetBlindEditMode: Boolean;
begin
  LoadSettings;
  Result := FBlindEditMode;
end;

procedure SetBlindEditMode(AValue: Boolean);
begin
  LoadSettings;
  FBlindEditMode := AValue;
  SaveSettings;
end;

function GetBackupLocation: string;
begin
  LoadSettings;
  Result := FBackupLocation;
end;

procedure SetBackupLocation(const AValue: string);
begin
  LoadSettings;
  FBackupLocation := AValue;
  SaveSettings;
end;

{ Server settings }

function GetServerSuite: string;
begin
  LoadSettings;
  Result := FServerSuite;
end;

procedure SetServerSuite(const AValue: string);
begin
  LoadSettings;
  FServerSuite := LowerCase(Trim(AValue));
  SaveSettings;
end;

function GetDataServer: string;
begin
  LoadSettings;
  Result := FDataServer;
end;

procedure SetDataServer(const AValue: string);
begin
  LoadSettings;
  FDataServer := AValue;
  SaveSettings;
end;

function GetMediaServer: string;
begin
  LoadSettings;
  Result := FMediaServer;
end;

procedure SetMediaServer(const AValue: string);
begin
  LoadSettings;
  FMediaServer := AValue;
  SaveSettings;
end;

function GetReaderServer: string;
begin
  LoadSettings;
  Result := FReaderServer;
end;

procedure SetReaderServer(const AValue: string);
begin
  LoadSettings;
  FReaderServer := AValue;
  SaveSettings;
end;

function GetCreateAccountURL: string;
begin
  LoadSettings;
  Result := FCreateAccountURL;
end;

procedure SetCreateAccountURL(const AValue: string);
begin
  LoadSettings;
  FCreateAccountURL := AValue;
  SaveSettings;
end;

function GetLanguagesURL: string;
begin
  LoadSettings;
  Result := FLanguagesURL;
end;

procedure SetLanguagesURL(const AValue: string);
begin
  LoadSettings;
  FLanguagesURL := AValue;
  SaveSettings;
end;

function GetIndexSQLiteURL: string;
begin
  LoadSettings;
  Result := FIndexSQLiteURL;
end;

procedure SetIndexSQLiteURL(const AValue: string);
begin
  LoadSettings;
  FIndexSQLiteURL := AValue;
  SaveSettings;
end;

function GetTranslationManualURL: string;
begin
  LoadSettings;
  Result := FTranslationManualURL;
end;

procedure SetTranslationManualURL(const AValue: string);
begin
  LoadSettings;
  FTranslationManualURL := AValue;
  SaveSettings;
end;

{ Developer settings }

function GetDeveloperTools: Boolean;
begin
  LoadSettings;
  Result := FDeveloperTools;
end;

procedure SetDeveloperTools(AValue: Boolean);
begin
  LoadSettings;
  FDeveloperTools := AValue;
  SaveSettings;
end;

{ Computed helpers }

procedure GetSuiteDefaults(const Suite: string;
  out ADataServer, AMediaServer, AReaderServer, ACreateAccountURL,
  ALanguagesURL, AIndexSQLiteURL, ATranslationManualURL: string);
begin
  if LowerCase(Trim(Suite)) = 'dcs' then
  begin
    ADataServer := DCS_DATA_SERVER;
    AMediaServer := DCS_MEDIA_SERVER;
    AReaderServer := DCS_READER_SERVER;
    ACreateAccountURL := '';
    ALanguagesURL := DCS_LANGUAGES_URL;
    AIndexSQLiteURL := DCS_INDEX_SQLITE_URL;
    ATranslationManualURL := DCS_TRANSLATION_MANUAL_URL;
  end
  else
  begin
    ADataServer := WACS_DATA_SERVER;
    AMediaServer := WACS_MEDIA_SERVER;
    AReaderServer := WACS_READER_SERVER;
    ACreateAccountURL := '';
    ALanguagesURL := WACS_LANGUAGES_URL;
    AIndexSQLiteURL := WACS_INDEX_SQLITE_URL;
    ATranslationManualURL := WACS_TRANSLATION_MANUAL_URL;
  end;
end;

procedure ApplyServerSuiteDefaults(const Suite: string);
var
  DS, MS, RS, CA, LU, IU, TU: string;
begin
  LoadSettings;
  GetSuiteDefaults(Suite, DS, MS, RS, CA, LU, IU, TU);
  FServerSuite := LowerCase(Trim(Suite));
  FDataServer := DS;
  FMediaServer := MS;
  FReaderServer := RS;
  FCreateAccountURL := CA;
  FLanguagesURL := LU;
  FIndexSQLiteURL := IU;
  FTranslationManualURL := TU;
  SaveSettings;
end;

function GetDefaultBackupLocation: string;
begin
  {$IFDEF LINUX}
  Result := IncludeTrailingPathDelimiter(GetEnvironmentVariable('HOME')) + 'BTT-Writer';
  {$ENDIF}
  {$IFDEF DARWIN}
  Result := IncludeTrailingPathDelimiter(GetEnvironmentVariable('HOME')) + 'BTT-Writer';
  {$ENDIF}
  {$IFDEF WINDOWS}
  Result := IncludeTrailingPathDelimiter(GetEnvironmentVariable('USERPROFILE')) + 'BTT-Writer';
  {$ENDIF}
end;

function GetEffectiveBackupLocation: string;
begin
  LoadSettings;
  Result := FBackupLocation;
  if Result = '' then
    Result := GetDefaultBackupLocation;
end;

function GetEffectiveDataServer: string;
var
  DS, MS, RS, CA, LU, IU, TU: string;
begin
  LoadSettings;
  Result := FDataServer;
  if Result = '' then
  begin
    GetSuiteDefaults(FServerSuite, DS, MS, RS, CA, LU, IU, TU);
    Result := DS;
  end;
end;

function GetEffectiveCreateAccountURL: string;
var
  DS, MS, RS, CA, LU, IU, TU: string;
begin
  LoadSettings;
  Result := FCreateAccountURL;
  if Result = '' then
  begin
    GetSuiteDefaults(FServerSuite, DS, MS, RS, CA, LU, IU, TU);
    Result := DS + '/user/sign_up';
  end;
end;

end.
