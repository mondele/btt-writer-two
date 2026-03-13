program bttwriter2;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  SysUtils, Interfaces, Forms,
  Globals, DataPaths, USFMUtils, BibleChunk, BibleChapter, BibleBook,
  ResourceContainer, ProjectManager, ProjectScanner,
  MainForm, ProjectEditForm, SplashScreen, AppSettings, AppLog,
  UserProfile, GiteaClient, LoginForm, IndexDatabase, SourceExtractor,
  LegalTexts, GitUtils, USFMExporter, ImportForm;

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

begin
  ParseCommandLine;
  Application.Scaled := True;
  Application.Initialize;
  InitLog;
  if Verbose then
    LogInfo('Debug/verbose mode enabled');
  InitializeAppSettings;
  ShowStartupSplash;
  UpdateStartupSplash(rsSplashInitializing);
  Application.CreateForm(TMainWindow, MainWindow);
  Application.Run;
end.
