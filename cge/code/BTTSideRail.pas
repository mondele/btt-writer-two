{$mode objfpc}{$H+}
unit BTTSideRail;

{ Left (or right in RTL) navigation rail.
  Fixed-width vertical strip containing the ⋮ menu button at the bottom
  and a slot for additional icon buttons added by the owning view. }

interface

uses
  Classes,
  CastleUIControls, CastleControls, CastleColors,
  BTTTheme;

const
  BTT_RAIL_W = 56;

type
  TBTTSideRail = class(TCastleRectangleControl)
  private
    FMenuBtn     : TCastleButton;
    FOnMenuClick : TNotifyEvent;
    procedure DoMenuClick(Sender: TObject);
  public
    constructor Create(AOwner: TComponent; const APalette: TBTTPalette); reintroduce;

    { Insert an icon button into the top region of the rail.
      Caller positions AControl vertically; horizontal centering is applied here. }
    procedure AddTopButton(AControl: TCastleUserInterface);

    { Fired when the user taps the ⋮ menu button. }
    property OnMenuClick: TNotifyEvent read FOnMenuClick write FOnMenuClick;
  end;

implementation

const
  BtnMargin = 10;

constructor TBTTSideRail.Create(AOwner: TComponent; const APalette: TBTTPalette);
begin
  inherited Create(AOwner);
  Color := APalette.RailBg;
  Width := BTT_RAIL_W;

  FMenuBtn := TCastleButton.Create(Self);
  FMenuBtn.Caption  := #$E2#$8B#$AE;  { UTF-8 ⋮  U+22EE VERTICAL ELLIPSIS }
  FMenuBtn.FontSize := 22;
  FMenuBtn.OnClick  := @DoMenuClick;
  FMenuBtn.Anchor(hpMiddle, hpMiddle);
  FMenuBtn.Anchor(vpBottom, vpBottom, BtnMargin);
  InsertFront(FMenuBtn);
end;

procedure TBTTSideRail.DoMenuClick(Sender: TObject);
begin
  if Assigned(FOnMenuClick) then
    FOnMenuClick(Self);
end;

procedure TBTTSideRail.AddTopButton(AControl: TCastleUserInterface);
begin
  AControl.Anchor(hpMiddle, hpMiddle);
  InsertFront(AControl);
end;

end.
