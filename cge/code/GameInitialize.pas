{$mode objfpc}{$H+}
unit GameInitialize;

{ Application entry point.
  Initialises settings, logging, and the user profile, then hands
  control to CGE's event loop via the home view. }

interface

{ ThemeChanged is called whenever the user updates the app theme setting.
  GameInitialize notifies all views so they can rebuild their palette. }
procedure ThemeChanged;

implementation

uses
  SysUtils,
  CastleWindow, CastleApplicationProperties, CastleLog, CastleUIControls,
  CastleFilesUtils, CastleUriUtils,
  AppSettings, AppLog, AppState, UserProfile,
  GameViewHome, GameViewEditor, GameViewChunkEdit, GameViewBlindEdit,
  GameViewLogin, GameViewSettings, GameViewNewProject, GameViewTerms,
  GameViewImport, GameViewRead, GameViewFeedback;

var
  Window: TCastleWindow;

procedure ThemeChanged;
begin
  ViewHome.OnThemeChange;
  ViewEditor.OnThemeChange;
  ViewChunkEdit.OnThemeChange;
  ViewBlindEdit.OnThemeChange;
  ViewLogin.OnThemeChange;
  ViewSettings.OnThemeChange;
  ViewNewProject.OnThemeChange;
  ViewTerms.OnThemeChange;
  ViewImport.OnThemeChange;
  ViewRead.OnThemeChange;
  ViewFeedback.OnThemeChange;
end;

procedure ApplicationInitialize;
var
  Profile: TUserProfile;
  DataDir: string;
begin
  { Settings must be first — other units read from it. }
  InitializeAppSettings;

  { Redirect CGE's own log through our AppLog file as well. }
  LogInfo('BTT-Writer CGE starting');

  { Load persisted user profile (empty username if not logged in). }
  if HasUserProfile then
  begin
    Profile := LoadUserProfile;
    GAppState.UserName := Profile.FullName;
    if GAppState.UserName = '' then
      GAppState.UserName := Profile.Username;
    GAppState.IsLocal := Profile.IsLocal;
  end
  else
    GAppState.UserName := '(not logged in)';

  { Pin castle-data:/ to the data/ folder next to the executable (not CWD).
    CGE's default Linux resolver falls back to GetCurrentDir, so running from
    the repo root would miss cge/data/. This makes the binary portable:
    ./btt-writer-cge works from any CWD as long as data/ sits beside it. }
  DataDir := ExtractFilePath(ParamStr(0)) + 'data' + PathDelim;
  if DirectoryExists(DataDir) then
    ApplicationDataOverride := FilenameToUriSafe(DataDir);

  { Load UI scaling and default font from data/CastleSettings.xml.
    Guard against missing data: fall back to hardcoded scaling so the
    app still runs (with the bitmap fallback font). }
  try
    Window.Container.LoadSettings('castle-data:/CastleSettings.xml');
  except
    on E: Exception do
    begin
      LogFmt(llWarn, 'LoadSettings failed (%s); using fallback UI scaling', [E.Message]);
      Window.Container.UIScaling        := usEncloseReferenceSize;
      Window.Container.UIReferenceWidth  := 1280;
      Window.Container.UIReferenceHeight := 800;
    end;
  end;

  { Create views once; they persist for the application lifetime. }
  ViewHome       := TViewHome.Create(Application);
  ViewEditor     := TViewEditor.Create(Application);
  ViewChunkEdit  := TViewChunkEdit.Create(Application);
  ViewBlindEdit  := TViewBlindEdit.Create(Application);
  ViewLogin      := TViewLogin.Create(Application);
  ViewSettings   := TViewSettings.Create(Application);
  ViewNewProject := TViewNewProject.Create(Application);
  ViewTerms      := TViewTerms.Create(Application);
  ViewImport     := TViewImport.Create(Application);
  ViewRead       := TViewRead.Create(Application);
  ViewFeedback   := TViewFeedback.Create(Application);

  GAppState.Screen := asHome;
  if not HasUserProfile then
    Window.Container.View := ViewLogin
  else if not GetTermsAccepted then
    Window.Container.View := ViewTerms
  else
    Window.Container.View := ViewHome;
end;

initialization
  Application.OnInitialize := @ApplicationInitialize;

  Window := TCastleWindow.Create(Application);
  Window.Caption := 'BTT-Writer';
  Window.Width   := 1280;
  Window.Height  := 800;

  Application.MainWindow := Window;
  Window.ParseParameters;

end.
