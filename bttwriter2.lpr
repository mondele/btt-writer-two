program bttwriter2;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Interfaces, Forms,
  Globals, DataPaths, USFMUtils, BibleChunk, BibleChapter, BibleBook,
  ResourceContainer, ProjectManager, ProjectScanner,
  MainForm, ProjectEditForm, SplashScreen, AppSettings;

resourcestring
  rsSplashInitializing = 'Initializing interface...';

{$R *.res}

begin
  Application.Scaled := True;
  Application.Initialize;
  InitializeAppSettings;
  ShowStartupSplash;
  UpdateStartupSplash(rsSplashInitializing);
  Application.CreateForm(TMainWindow, MainWindow);
  Application.Run;
end.
