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
  CastleWindow, CastleApplicationProperties, CastleLog,
  AppSettings, AppLog, AppState, UserProfile,
  GameViewHome, GameViewEditor;

var
  Window: TCastleWindow;

procedure ThemeChanged;
begin
  ViewHome.OnThemeChange;
  ViewEditor.OnThemeChange;
end;

procedure ApplicationInitialize;
var
  Profile: TUserProfile;
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

  { Apply UI scaling from data/CastleSettings.xml. }
  Window.Container.LoadSettings('castle-data:/CastleSettings.xml');

  { Create views once; they persist for the application lifetime. }
  ViewHome   := TViewHome.Create(Application);
  ViewEditor := TViewEditor.Create(Application);

  GAppState.Screen := asHome;
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
