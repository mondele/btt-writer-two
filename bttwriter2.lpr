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

{$R *.res}

begin
  Application.Scaled := True;
  Application.Initialize;
  ShowStartupSplash;
  UpdateStartupSplash('Initializing interface...');
  Application.CreateForm(TMainWindow, MainWindow);
  UpdateStartupSplash('Startup complete');
  HideStartupSplash;
  Application.Run;
end.
