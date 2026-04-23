{$mode objfpc}{$H+}
unit BTTStatusBar;

{ Persistent bottom status strip.

  Matches v1: narrow navy bar at the bottom of every view showing
  'Status: <msg>' in small light text.  Views insert one of these at
  the bottom of their chrome and call SetStatus as state changes. }

interface

uses
  Classes,
  CastleUIControls, CastleControls, CastleColors,
  BTTTheme;

const
  BTT_STATUS_H = 26;

type
  TBTTStatusBar = class(TCastleRectangleControl)
  private
    FLbl: TCastleLabel;
  public
    constructor Create(AOwner: TComponent; const APalette: TBTTPalette); reintroduce;
    procedure SetStatus(const AMsg: string);
  end;

implementation

constructor TBTTStatusBar.Create(AOwner: TComponent; const APalette: TBTTPalette);
begin
  inherited Create(AOwner);
  Color  := APalette.HeaderBg;
  Height := BTT_STATUS_H;

  FLbl          := TCastleLabel.Create(Self);
  FLbl.Caption  := 'Status:  Idle';
  FLbl.Color    := APalette.HeaderText;
  FLbl.FontSize := 12;
  FLbl.Anchor(hpLeft, hpLeft, 12);
  FLbl.Anchor(vpMiddle, vpMiddle);
  InsertFront(FLbl);
end;

procedure TBTTStatusBar.SetStatus(const AMsg: string);
begin
  if AMsg = '' then
    FLbl.Caption := 'Status:  Idle'
  else
    FLbl.Caption := 'Status:  ' + AMsg;
end;

end.
