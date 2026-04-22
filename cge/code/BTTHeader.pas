{$mode objfpc}{$H+}
unit BTTHeader;

{ Reusable BTT-Writer header bar.
  Fixed height strip at the top of any view; provides a centered title
  and left/right anchor slots for buttons and labels. }

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
    FTitleLbl: TCastleLabel;
  public
    { Create a styled header and insert it into the parent view.
      Caller is responsible for setting Translation/Width in Resize. }
    constructor Create(AOwner: TComponent; const APalette: TBTTPalette); reintroduce;

    { Update the centred title text. }
    procedure SetTitle(const ATitle: string);

    { Anchor a control to the left edge (e.g. back button).
      The caller must have already created the control with FreeAtStop. }
    procedure AddLeft(AControl: TCastleUserInterface);

    { Anchor a control to the right edge (e.g. user-name label). }
    procedure AddRight(AControl: TCastleUserInterface);
  end;

implementation

const
  SlotPad = 12;

constructor TBTTHeader.Create(AOwner: TComponent; const APalette: TBTTPalette);
begin
  inherited Create(AOwner);
  Color  := APalette.HeaderBg;
  Height := BTT_HEADER_H;

  FTitleLbl := TCastleLabel.Create(Self);
  FTitleLbl.Color    := APalette.HeaderText;
  FTitleLbl.FontSize := 20;
  FTitleLbl.Anchor(hpMiddle, hpMiddle);
  FTitleLbl.Anchor(vpMiddle, vpMiddle);
  InsertFront(FTitleLbl);
end;

procedure TBTTHeader.SetTitle(const ATitle: string);
begin
  FTitleLbl.Caption := ATitle;
end;

procedure TBTTHeader.AddLeft(AControl: TCastleUserInterface);
begin
  AControl.Anchor(hpLeft, hpLeft, SlotPad);
  AControl.Anchor(vpMiddle, vpMiddle);
  InsertFront(AControl);
end;

procedure TBTTHeader.AddRight(AControl: TCastleUserInterface);
begin
  AControl.Anchor(hpRight, hpRight, -SlotPad);
  AControl.Anchor(vpMiddle, vpMiddle);
  InsertFront(AControl);
end;

end.
