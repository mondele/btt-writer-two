{$mode objfpc}{$H+}
unit CGEViewBase;

{ Base class for all BTT-Writer CGE views.
  Provides:
    - Current theme palette via P (shorthand for GetCurrentPalette)
    - RTL flag via IsRTL (from GAppState.Editor)
    - ApplyBackground: fills the view with the window background colour
    - OnThemeChange notification hook (called by GameInitialize when the
      theme setting changes; override to rebuild themed controls)
}

interface

uses
  CastleUIControls, CastleControls, CastleColors,
  BTTTheme, AppState;

type
  TCGEViewBase = class(TCastleView)
  private
    FBg: TCastleRectangleControl;
  protected
    { Shorthand for the current palette — valid after Start. }
    function P: TBTTPalette;
    { True when the editor is in RTL mode. }
    function IsRTL: Boolean;
    { Fill the root with the window background colour.
      Call once in Start before inserting other controls. }
    procedure ApplyBackground;
  public
    { Called by GameInitialize when the user changes the theme.
      Default implementation does nothing; override to rebuild UI. }
    procedure OnThemeChange; virtual;
  end;

implementation

{ TCGEViewBase }

function TCGEViewBase.P: TBTTPalette;
begin
  Result := GetCurrentPalette;
end;

function TCGEViewBase.IsRTL: Boolean;
begin
  Result := GAppState.Editor.IsRTL;
end;

procedure TCGEViewBase.ApplyBackground;
begin
  FBg := TCastleRectangleControl.Create(FreeAtStop);
  FBg.Color := P.WindowBg;
  FBg.FullSize := True;
  InsertFront(FBg);
end;

procedure TCGEViewBase.OnThemeChange;
begin
  { Nothing by default. }
end;

end.
