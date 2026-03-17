program bttwriter2;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  SysUtils, Interfaces, Forms, Graphics,
  Globals, DataPaths, USFMUtils, BibleChunk, BibleChapter, BibleBook,
  ResourceContainer, ProjectManager, ProjectScanner,
  MainForm, ProjectEditForm, SplashScreen, AppSettings, AppLog,
  UserProfile, GiteaClient, LoginForm, IndexDatabase, SourceExtractor,
  LegalTexts, GitUtils, USFMExporter, ImportForm, ConflictResolver,
  DevToolsForm;

resourcestring
  rsSplashInitializing = 'Initializing interface...';

{$R *.res}

procedure ParseCommandLine;
var
  I: Integer;
begin
  for I := 1 to ParamCount do
  begin
    if (ParamStr(I) = '--debug') or (ParamStr(I) = '--verbose') then
      Verbose := True;
  end;
end;

procedure LoadAppIcon;
var
  IconPath: string;
  Png: TPortableNetworkGraphic;
begin
  { If the icon is already set (e.g. from compiled resources on Windows), skip }
  if not Application.Icon.Empty then
    Exit;
  { Developer fallback: load PNG from next to the executable }
  IconPath := ExtractFilePath(ParamStr(0)) + 'bttwriter2.png';
  if not FileExists(IconPath) then
    Exit;
  Png := TPortableNetworkGraphic.Create;
  try
    Png.LoadFromFile(IconPath);
    Application.Icon.Assign(Png);
  finally
    Png.Free;
  end;
end;

begin
  ParseCommandLine;
  Application.Scaled := True;
  Application.Initialize;
  LoadAppIcon;
  InitLog;
  if Verbose then
    LogInfo('Debug/verbose mode enabled');
  InitializeAppSettings;
  ShowStartupSplash;
  UpdateStartupSplash(rsSplashInitializing);
  Application.CreateForm(TMainWindow, MainWindow);
  Application.Run;
end.
