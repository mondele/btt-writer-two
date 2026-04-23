{$mode objfpc}{$H+}
unit BTTHeader;

{ Reusable BTT-Writer header bar.
  Fixed height strip at the top of any view; provides a centered title
  and left/right anchor slots for buttons and labels.

  Multiple controls can be added to each side; they are packed into
  horizontal groups so they flow naturally without overlapping. }

interface

uses
  Classes,
  CastleUIControls, CastleControls, CastleColors,
  BTTTheme;

const
  BTT_HEADER_H = 60;

type
  TBTTHeader = class(TCastleRectangleControl)
  private
    FTitleLbl  : TCastleLabel;
    FLeftGroup : TCastleHorizontalGroup;
    FRightGroup: TCastleHorizontalGroup;
  public
    constructor Create(AOwner: TComponent; const APalette: TBTTPalette); reintroduce;
    procedure SetTitle(const ATitle: string);
    { Append a control to the left group (e.g. back button). }
    procedure AddLeft(AControl: TCastleUserInterface);
    { Append a control to the right group (e.g. mode buttons). }
    procedure AddRight(AControl: TCastleUserInterface);
  end;

implementation

const
  SlotPad = 10;
  BtnGap  = 6;

constructor TBTTHeader.Create(AOwner: TComponent; const APalette: TBTTPalette);
begin
  inherited Create(AOwner);
  Color  := APalette.HeaderBg;
  Height := BTT_HEADER_H;

  { Centred title }
  FTitleLbl := TCastleLabel.Create(Self);
  FTitleLbl.Color    := APalette.HeaderText;
  FTitleLbl.FontSize := 20;
  FTitleLbl.Anchor(hpMiddle, hpMiddle);
  FTitleLbl.Anchor(vpMiddle, vpMiddle);
  InsertFront(FTitleLbl);

  { Left group — left-anchored, children added left-to-right }
  FLeftGroup        := TCastleHorizontalGroup.Create(Self);
  FLeftGroup.Spacing := BtnGap;
  FLeftGroup.Anchor(hpLeft, hpLeft, SlotPad);
  FLeftGroup.Anchor(vpMiddle, vpMiddle);
  InsertFront(FLeftGroup);

  { Right group — right-anchored, children added left-to-right.
    The last added button ends up closest to the right edge because
    TCastleHorizontalGroup grows leftward when right-anchored. }
  FRightGroup        := TCastleHorizontalGroup.Create(Self);
  FRightGroup.Spacing := BtnGap;
  FRightGroup.Anchor(hpRight, hpRight, -SlotPad);
  FRightGroup.Anchor(vpMiddle, vpMiddle);
  InsertFront(FRightGroup);
end;

procedure TBTTHeader.SetTitle(const ATitle: string);
begin
  FTitleLbl.Caption := ATitle;
end;

procedure TBTTHeader.AddLeft(AControl: TCastleUserInterface);
begin
  FLeftGroup.InsertFront(AControl);
end;

procedure TBTTHeader.AddRight(AControl: TCastleUserInterface);
begin
  FRightGroup.InsertFront(AControl);
end;

end.
