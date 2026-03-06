unit AppSettings;

{$mode objfpc}{$H+}

interface

uses
  Forms;

type
  TAppTheme = (atLight, atDark);

procedure InitializeAppSettings;
function GetAppTheme: TAppTheme;
procedure SetAppTheme(ATheme: TAppTheme; Persist: Boolean = True);
function ThemeToID(ATheme: TAppTheme): string;
function ThemeFromID(const S: string): TAppTheme;

implementation

uses
  SysUtils, Classes, fpjson, jsonparser, DataPaths;

var
  FTheme: TAppTheme = atLight;
  FLoaded: Boolean = False;

function SettingsPath: string;
begin
  Result := IncludeTrailingPathDelimiter(GetDataPath) + 'settings.json';
end;

function ThemeToID(ATheme: TAppTheme): string;
begin
  case ATheme of
    atDark: Result := 'dark';
  else
    Result := 'light';
  end;
end;

function ThemeFromID(const S: string): TAppTheme;
begin
  if SameText(Trim(S), 'dark') then
    Result := atDark
  else
    Result := atLight;
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
  FTheme := atLight;
  Path := SettingsPath;
  if not FileExists(Path) then
    Exit;

  SL := TStringList.Create;
  try
    SL.LoadFromFile(Path);
    Data := GetJSON(SL.Text);
    try
      if Data is TJSONObject then
      begin
        Obj := TJSONObject(Data);
        FTheme := ThemeFromID(Obj.Get('theme', 'light'));
      end;
    finally
      Data.Free;
    end;
  finally
    SL.Free;
  end;
end;

procedure InitializeAppSettings;
begin
  LoadSettings;
end;

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

end.
