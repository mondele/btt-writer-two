{$mode objfpc}{$H+}
unit BTTBreadcrumb;

{ Sub-header breadcrumb strip for nested screens.

  Matches v1: a bright-blue bar below the main header containing:
    - ← back arrow (optional, enabled when OnBack is assigned)
    - Crumb trail:  "Home  >  Settings"
    - Optional right slot (for a title or toggle — currently unused)

  Usage:
    Crumb := TBTTBreadcrumb.Create(FreeAtStop, Pal);
    Crumb.SetCrumbs(['Home', 'Settings']);
    Crumb.OnBack := @ClickBack;
    InsertFront(Crumb);
    Size and position in Resize — full width, pinned under the header.
}

interface

uses
  Classes,
  CastleUIControls, CastleControls, CastleColors,
  BTTTheme;

const
  BTT_BREADCRUMB_H = 44;

type
  TBTTBreadcrumb = class(TCastleRectangleControl)
  private
    FPalette    : TBTTPalette;
    FBackBtn    : TCastleButton;
    FCrumbGroup : TCastleHorizontalGroup;
    FOnBack     : TNotifyEvent;
    procedure DoBackClick(Sender: TObject);
    procedure UpdateBackVisible;
  public
    constructor Create(AOwner: TComponent; const APalette: TBTTPalette); reintroduce;

    { Replace the crumb trail.  Pass e.g. ['Home', 'Settings']. }
    procedure SetCrumbs(const ACrumbs: array of string);

    { Fires when the user taps the ← arrow.  When nil, the arrow is hidden. }
    property OnBack: TNotifyEvent read FOnBack write FOnBack;
  end;

implementation

uses
  CastleVectors;

const
  SlotPad  = 14;
  BackBtnW = 32;

constructor TBTTBreadcrumb.Create(AOwner: TComponent; const APalette: TBTTPalette);
begin
  inherited Create(AOwner);
  FPalette := APalette;
  Color    := APalette.Primary;
  Height   := BTT_BREADCRUMB_H;

  { Back arrow — flat transparent button on the blue bar. }
  FBackBtn             := TCastleButton.Create(Self);
  FBackBtn.Caption     := #$E2#$86#$90;  { ← U+2190 }
  FBackBtn.FontSize    := 20;
  FBackBtn.CustomBackground    := True;
  FBackBtn.CustomColorNormal   := Vector4(0, 0, 0, 0);
  FBackBtn.CustomColorFocused  := Vector4(1, 1, 1, 0.12);
  FBackBtn.CustomColorPressed  := Vector4(1, 1, 1, 0.22);
  FBackBtn.CustomColorDisabled := Vector4(0, 0, 0, 0);
  FBackBtn.CustomTextColorUse  := True;
  FBackBtn.CustomTextColor     := APalette.HeaderText;
  FBackBtn.AutoSize            := False;
  FBackBtn.Width               := BackBtnW;
  FBackBtn.Height              := BTT_BREADCRUMB_H - 6;
  FBackBtn.OnClick             := @DoBackClick;
  FBackBtn.Anchor(hpLeft, hpLeft, SlotPad - 4);
  FBackBtn.Anchor(vpMiddle, vpMiddle);
  InsertFront(FBackBtn);

  { Crumb trail group — starts after the back arrow. }
  FCrumbGroup         := TCastleHorizontalGroup.Create(Self);
  FCrumbGroup.Spacing := 10;
  FCrumbGroup.Anchor(hpLeft, hpLeft, SlotPad + BackBtnW + 4);
  FCrumbGroup.Anchor(vpMiddle, vpMiddle);
  InsertFront(FCrumbGroup);

  UpdateBackVisible;
end;

procedure TBTTBreadcrumb.UpdateBackVisible;
begin
  FBackBtn.Exists := Assigned(FOnBack);
end;

procedure TBTTBreadcrumb.DoBackClick(Sender: TObject);
begin
  if Assigned(FOnBack) then
    FOnBack(Self);
end;

procedure TBTTBreadcrumb.SetCrumbs(const ACrumbs: array of string);
var
  I : Integer;
  Lbl : TCastleLabel;
  Sep : TCastleLabel;
begin
  UpdateBackVisible;

  { Clear existing crumb children — group owns them. }
  while FCrumbGroup.ControlsCount > 0 do
    FCrumbGroup.Controls[0].Free;

  for I := 0 to High(ACrumbs) do
  begin
    if I > 0 then
    begin
      Sep          := TCastleLabel.Create(FCrumbGroup);
      Sep.Caption  := #$E2#$9D#$AF;   { ❯  U+276F right-pointing chevron — white-on-blue }
      Sep.Color    := FPalette.HeaderText;
      Sep.FontSize := 14;
      FCrumbGroup.InsertFront(Sep);
    end;

    Lbl          := TCastleLabel.Create(FCrumbGroup);
    Lbl.Caption  := ACrumbs[I];
    Lbl.Color    := FPalette.HeaderText;
    Lbl.FontSize := 18;
    FCrumbGroup.InsertFront(Lbl);
  end;
end;

end.
