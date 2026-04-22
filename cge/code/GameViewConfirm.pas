{$mode objfpc}{$H+}
unit GameViewConfirm;

{ Yes/No confirmation modal dialog.

  Usage:
    FConfirm := TViewConfirm.Create(Self, 'Are you sure?');
    Container.PushView(FConfirm);

  Parent view's Resume:
    if Assigned(FConfirm) then
    begin
      if FConfirm.Answer then DoTheThing;
      FreeAndNil(FConfirm);
    end;
}

interface

uses
  Classes,
  CastleUIControls, CastleControls, CastleColors, CastleVectors,
  CGEViewBase;

type
  TViewConfirm = class(TCGEModalBase)
  private
    FMsg    : string;
    FAnswer : Boolean;
    procedure ClickYes(Sender: TObject);
    procedure ClickNo(Sender: TObject);
  public
    constructor Create(AOwner: TComponent; const AMsg: string); reintroduce;
    procedure Start; override;
    { True if the user chose Yes; False if No or if dismissed. }
    property Answer: Boolean read FAnswer;
  end;

implementation

uses
  BTTTheme;

const
  BtnW  = 100;
  BtnH  = 36;
  Pad   = 20;

constructor TViewConfirm.Create(AOwner: TComponent; const AMsg: string);
begin
  inherited Create(AOwner);
  FMsg       := AMsg;
  FAnswer    := False;
  PanelWidth := 420;
  PanelHeight := 180;
end;

procedure TViewConfirm.Start;
var
  Pal : TBTTPalette;
  Lbl : TCastleLabel;
  BtnYes, BtnNo: TCastleButton;
begin
  inherited;  { creates ContentPanel }
  Pal := P;

  { Message label }
  Lbl           := TCastleLabel.Create(FreeAtStop);
  Lbl.Caption   := FMsg;
  Lbl.Color     := Pal.TextPrimary;
  Lbl.FontSize  := 16;
  Lbl.Alignment := hpMiddle;
  Lbl.Anchor(hpMiddle, hpMiddle);
  Lbl.Anchor(vpTop, vpTop, -(Pad + 16));
  ContentPanel.InsertFront(Lbl);

  { Yes button — right of centre }
  BtnYes          := TCastleButton.Create(FreeAtStop);
  BtnYes.Caption  := 'Yes';
  BtnYes.FontSize := 14;
  BtnYes.Width    := BtnW;
  BtnYes.Height   := BtnH;
  BtnYes.OnClick  := @ClickYes;
  BtnYes.Anchor(hpMiddle, hpMiddle, 60);
  BtnYes.Anchor(vpBottom, vpBottom, Pad);
  ContentPanel.InsertFront(BtnYes);

  { No button — left of centre }
  BtnNo          := TCastleButton.Create(FreeAtStop);
  BtnNo.Caption  := 'No';
  BtnNo.FontSize := 14;
  BtnNo.Width    := BtnW;
  BtnNo.Height   := BtnH;
  BtnNo.OnClick  := @ClickNo;
  BtnNo.Anchor(hpMiddle, hpMiddle, -60);
  BtnNo.Anchor(vpBottom, vpBottom, Pad);
  ContentPanel.InsertFront(BtnNo);
end;

procedure TViewConfirm.ClickYes(Sender: TObject);
begin
  FAnswer := True;
  Close;
end;

procedure TViewConfirm.ClickNo(Sender: TObject);
begin
  FAnswer := False;
  Close;
end;

end.
