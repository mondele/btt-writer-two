{$mode objfpc}{$H+}
unit CGEViewBase;

{ Base classes for BTT-Writer CGE views.

  TCGEViewBase — base for all full-screen views.
    - P (shorthand for current palette)
    - IsRTL flag
    - ApplyBackground: opaque window background fill
    - OnThemeChange notification hook

  TCGEModalBase — base for modal overlay views.
    - Uses PushView/PopView pattern (see CastleDialogViews docs)
    - Dimmed semi-transparent overlay; centered content panel
    - InterceptInput := True blocks input to views behind
    - Close calls Container.PopView(Self)
    - PanelWidth / PanelHeight control the card size before Start
}

interface

uses
  Classes,
  CastleUIControls, CastleControls, CastleColors, CastleVectors,
  BTTTheme, AppState;

type
  { Full-screen view base. }
  TCGEViewBase = class(TCastleView)
  private
    FBg: TCastleRectangleControl;
  protected
    function P: TBTTPalette;
    function IsRTL: Boolean;
    procedure ApplyBackground;
  public
    procedure OnThemeChange; virtual;
  end;

  { Modal overlay view base.
    Usage:
      Dial := TViewConfirm.Create(Self);
      Container.PushView(Dial);
      // parent view's Resume checks Dial.Answer and FreeAndNil(Dial)
  }
  TCGEModalBase = class(TCGEViewBase)
  private
    FPanel  : TCastleRectangleControl;
    FPanelW : Single;
    FPanelH : Single;
  protected
    { The content card — subclasses insert child controls here. }
    property ContentPanel: TCastleRectangleControl read FPanel;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Start; override;
    procedure Resize; override;

    { Dismiss this modal and return to the view below. }
    procedure Close;

    { Size of the centered content panel. Set before Start is called. }
    property PanelWidth : Single read FPanelW write FPanelW;
    property PanelHeight: Single read FPanelH write FPanelH;
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
  FBg.Color    := P.WindowBg;
  FBg.FullSize := True;
  InsertFront(FBg);
end;

procedure TCGEViewBase.OnThemeChange;
begin
end;

{ TCGEModalBase }

constructor TCGEModalBase.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FPanelW := 480;
  FPanelH := 280;
end;

procedure TCGEModalBase.Start;
var
  Overlay: TCastleRectangleControl;
  Pal: TBTTPalette;
begin
  inherited;
  Pal := P;

  InterceptInput := True;

  { Semi-transparent dark overlay — lets the view behind show through. }
  Overlay          := TCastleRectangleControl.Create(FreeAtStop);
  Overlay.Color    := Vector4(0, 0, 0, 0.45);
  Overlay.FullSize := True;
  InsertFront(Overlay);

  { Centered content card. }
  FPanel       := TCastleRectangleControl.Create(FreeAtStop);
  FPanel.Color := Pal.PanelBg;
  FPanel.Width := FPanelW;
  FPanel.Height := FPanelH;
  FPanel.Anchor(hpMiddle, hpMiddle);
  FPanel.Anchor(vpMiddle, vpMiddle);
  InsertFront(FPanel);
end;

procedure TCGEModalBase.Resize;
begin
  inherited;
  { Panel centering is handled by anchors; nothing extra needed here. }
end;

procedure TCGEModalBase.Close;
begin
  Container.PopView(Self);
end;

end.
