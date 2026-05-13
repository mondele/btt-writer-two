{$mode objfpc}{$H+}
unit GameViewConfirm;

{ Yes/No confirmation modal dialog.

  Layout loaded from castle-data:/designs/confirm.castle-user-interface.
  ContentPanel is created by TCGEModalBase.Start; design root is inserted
  into it.

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
  CastleComponentSerialize,
  BTTTheme;

constructor TViewConfirm.Create(AOwner: TComponent; const AMsg: string);
begin
  inherited Create(AOwner);
  FMsg        := AMsg;
  FAnswer     := False;
  PanelWidth  := 420;
  PanelHeight := 180;
end;

procedure TViewConfirm.Start;
var
  Pal    : TBTTPalette;
  Root   : TCastleUserInterface;
  MsgLbl : TCastleLabel;
  BtnYes,
  BtnNo  : TCastleButton;
begin
  inherited;  { creates ContentPanel }
  Pal := P;

  Root := ComponentLoad(
    'castle-data:/designs/confirm.castle-user-interface',
    FreeAtStop) as TCastleUserInterface;
  ContentPanel.InsertFront(Root);

  MsgLbl := FreeAtStop.FindRequiredComponent('MsgLbl') as TCastleLabel;
  BtnYes := FreeAtStop.FindRequiredComponent('BtnYes') as TCastleButton;
  BtnNo  := FreeAtStop.FindRequiredComponent('BtnNo')  as TCastleButton;

  MsgLbl.Caption := FMsg;
  MsgLbl.Color   := Pal.TextPrimary;
  BtnYes.OnClick := @ClickYes;
  BtnNo.OnClick  := @ClickNo;
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
