{$mode objfpc}{$H+}
unit BTTPopupMenu;

{ Vertical popup menu panel.
  Usage:
    1. Create (passing FreeAtStop + palette).
    2. Call AddItem for each entry.
    3. Call Build once after all AddItem calls.
    4. Toggle visibility with Exists := not Exists.
    5. Each item's OnClick handler must set Exists := False to dismiss.
  Caller positions the panel via Translation in Resize. }

interface

uses
  Classes,
  CastleUIControls, CastleControls, CastleColors,
  BTTTheme;

const
  BTT_POPUP_ITEM_H = 44;
  BTT_POPUP_W      = 230;

type
  TMenuItemDef = record
    Caption : string;
    Icon    : string;   { optional single-glyph icon, or '' for none }
    Handler : TNotifyEvent;
  end;

  TBTTPopupMenu = class(TCastleRectangleControl)
  private
    FPalette  : TBTTPalette;
    FItemDefs : array of TMenuItemDef;
  public
    constructor Create(AOwner: TComponent; const APalette: TBTTPalette); reintroduce;

    { Register a menu item — call before Build. }
    procedure AddItem(const ACaption: string; AOnClick: TNotifyEvent); overload;
    procedure AddItem(const ACaption, AIcon: string; AOnClick: TNotifyEvent); overload;

    { Construct button children from registered items.
      Call once after the last AddItem. }
    procedure Build;
  end;

implementation

uses
  CastleVectors;

constructor TBTTPopupMenu.Create(AOwner: TComponent; const APalette: TBTTPalette);
begin
  inherited Create(AOwner);
  FPalette := APalette;
  Color    := APalette.PanelBg;
  Width    := BTT_POPUP_W;
  Exists   := False;
end;

procedure TBTTPopupMenu.AddItem(const ACaption: string; AOnClick: TNotifyEvent);
begin
  AddItem(ACaption, '', AOnClick);
end;

procedure TBTTPopupMenu.AddItem(const ACaption, AIcon: string; AOnClick: TNotifyEvent);
var
  N: Integer;
begin
  N := Length(FItemDefs);
  SetLength(FItemDefs, N + 1);
  FItemDefs[N].Caption := ACaption;
  FItemDefs[N].Icon    := AIcon;
  FItemDefs[N].Handler := AOnClick;
end;

procedure TBTTPopupMenu.Build;
var
  TotalH, ItemY: Single;
  I: Integer;
  Btn: TCastleButton;
  Div1: TCastleRectangleControl;
  IconLbl: TCastleLabel;
begin
  if Length(FItemDefs) = 0 then Exit;

  TotalH := Length(FItemDefs) * BTT_POPUP_ITEM_H;
  Height := TotalH;

  for I := 0 to High(FItemDefs) do
  begin
    { Items stack top→bottom; bottom-left Y in CGE coords (Y increases upward) }
    ItemY := TotalH - (I + 1) * BTT_POPUP_ITEM_H;

    Btn              := TCastleButton.Create(Self);
    Btn.Caption      := '    ' + FItemDefs[I].Caption;
    Btn.FontSize     := 15;
    Btn.Width        := BTT_POPUP_W;
    Btn.Height       := BTT_POPUP_ITEM_H;
    Btn.Translation  := Vector2(0, ItemY);
    Btn.OnClick      := FItemDefs[I].Handler;
    InsertFront(Btn);

    { Icon overlay — rendered on top of the button, left-aligned. }
    if FItemDefs[I].Icon <> '' then
    begin
      IconLbl          := TCastleLabel.Create(Self);
      IconLbl.Caption  := FItemDefs[I].Icon;
      IconLbl.Color    := FPalette.TextSecondary;
      IconLbl.FontSize := 16;
      IconLbl.Translation := Vector2(14, ItemY + BTT_POPUP_ITEM_H / 2 - 8);
      InsertFront(IconLbl);
    end;

    { Separator above all items except the first }
    if I > 0 then
    begin
      Div1            := TCastleRectangleControl.Create(Self);
      Div1.Color      := FPalette.Border;
      Div1.Width      := BTT_POPUP_W;
      Div1.Height     := 1;
      Div1.Translation := Vector2(0, ItemY + BTT_POPUP_ITEM_H - 1);
      InsertFront(Div1);
    end;
  end;
end;

end.
