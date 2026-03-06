program bttwriter2;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Interfaces, Forms,
  Globals, DataPaths, USFMUtils, BibleChunk, BibleChapter, BibleBook,
  ResourceContainer, ProjectManager, ProjectScanner,
  MainForm, ProjectEditForm, SplashScreen;

resourcestring
  rsSplashInitializing = 'Initializing interface...';
  rsSplashStartupComplete = 'Startup complete';

{$R *.res}

begin
  Application.Scaled := True;
  Application.Initialize;
  ShowStartupSplash;
  UpdateStartupSplash(rsSplashInitializing);
  Application.CreateForm(TMainWindow, MainWindow);
  UpdateStartupSplash(rsSplashStartupComplete);
  HideStartupSplash;
  Application.Run;
end.
