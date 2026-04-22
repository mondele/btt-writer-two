{$mode objfpc}{$H+}
unit GameInitialize;

{ Application entry point: creates the window and the two spike views,
  sets the initial view, and hands off to CGE's event loop. }

interface

implementation

uses
  SysUtils,
  CastleWindow, CastleApplicationProperties, CastleLog,
  AppState, GameViewHome, GameViewEditor;

var
  Window: TCastleWindow;

procedure ApplicationInitialize;
begin
  { Create views once; they persist for the application lifetime. }
  ViewHome   := TViewHome.Create(Application);
  ViewEditor := TViewEditor.Create(Application);

  GAppState.Screen := asHome;
  Window.Container.View := ViewHome;
end;

initialization
  Application.OnInitialize := @ApplicationInitialize;

  Window := TCastleWindow.Create(Application);
  Window.Caption := 'BTT-Writer — CGE Spike';
  Window.Width   := 1280;
  Window.Height  := 800;

  Application.MainWindow := Window;
  Window.ParseParameters;

end.
