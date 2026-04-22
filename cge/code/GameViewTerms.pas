{$mode objfpc}{$H+}
unit GameViewTerms;

{ Terms of Use screen.

  Shown after login when terms have not yet been accepted.
  Presents three documents the user must review:
    1. License Agreement (CC BY-SA 4.0)
    2. Translation Guidelines
    3. Statement of Faith

  Each document has a green "Read" indicator that the user ticks by
  pressing the button.  The "Agree" button is enabled only after all
  three have been read.  Decline navigates back to Login.

  On Agree: SetTermsAccepted(True) → Container.View := ViewHome.
}

interface

uses
  Classes,
  CastleUIControls, CastleControls, CastleColors,
  CGEViewBase;

type
  TViewTerms = class(TCGEViewBase)
  private
    FCard        : TCastleRectangleControl;
    FTitleLbl    : TCastleLabel;
    FDescLbl     : TCastleLabel;

    { One row per document }
    FDocRow      : array[0..2] of TCastleRectangleControl;
    FDocLabel    : array[0..2] of TCastleLabel;
    FDocBtn      : array[0..2] of TCastleButton;
    FDocRead     : array[0..2] of Boolean;

    FAgreeBtn    : TCastleButton;
    FDeclineBtn  : TCastleButton;

    { Detail panel — shows full text of a document }
    FDetailPanel : TCastleRectangleControl;
    FDetailTitle : TCastleLabel;
    FDetailScroll: TCastleScrollView;
    FDetailText  : TCastleLabel;
    FDetailClose : TCastleButton;
    FDetailDocIdx: Integer;

    procedure BuildChrome;
    procedure ShowList;
    procedure ShowDetail(DocIdx: Integer);
    procedure UpdateAgreeButton;

    procedure ClickDoc0(Sender: TObject);
    procedure ClickDoc1(Sender: TObject);
    procedure ClickDoc2(Sender: TObject);
    procedure ClickClose(Sender: TObject);
    procedure ClickAgree(Sender: TObject);
    procedure ClickDecline(Sender: TObject);
  public
    procedure Start;    override;
    procedure Resize;   override;
    procedure OnThemeChange; override;
  end;

var
  ViewTerms: TViewTerms;

implementation

uses
  SysUtils, CastleVectors,
  AppSettings, AppLog, BTTTheme,
  LegalTexts,
  GameViewHome, GameViewLogin;

const
  CardW    = 520;
  CardH    = 380;
  Pad      = 24;
  RowH     = 52;
  BtnW     = 110;

{ Document metadata }
const
  DocTitles : array[0..2] of string = (
    'License Agreement',
    'Translation Guidelines',
    'Statement of Faith'
  );

function DocBody(Idx: Integer): string;
begin
  case Idx of
    0: Result := rsLicenseAgreement;
    1: Result := rsTranslationGuidelines;
    2: Result := rsStatementOfFaith;
  else
    Result := '';
  end;
end;

procedure TViewTerms.Start;
begin
  inherited;
  ApplyBackground;
  FDetailDocIdx := -1;
  FDocRead[0]   := False;
  FDocRead[1]   := False;
  FDocRead[2]   := False;
  BuildChrome;
  ShowList;
end;

procedure TViewTerms.BuildChrome;
var
  Pal  : TBTTPalette;
  I    : Integer;
  Row  : TCastleRectangleControl;
  Lbl  : TCastleLabel;
  Btn  : TCastleButton;
  YPos : Single;
begin
  Pal := P;

  { ── Centred card ── }
  FCard        := TCastleRectangleControl.Create(FreeAtStop);
  FCard.Color  := Pal.PanelBg;
  FCard.Width  := CardW;
  FCard.Height := CardH;
  FCard.Anchor(hpMiddle, hpMiddle);
  FCard.Anchor(vpMiddle, vpMiddle);
  InsertFront(FCard);

  FTitleLbl          := TCastleLabel.Create(FreeAtStop);
  FTitleLbl.Caption  := 'Terms of Use';
  FTitleLbl.Color    := Pal.TextPrimary;
  FTitleLbl.FontSize := 22;
  FTitleLbl.Anchor(hpMiddle, hpMiddle);
  FTitleLbl.Anchor(vpTop, vpTop, -Pad);
  FCard.InsertFront(FTitleLbl);

  FDescLbl          := TCastleLabel.Create(FreeAtStop);
  FDescLbl.Caption  := 'Please read and agree to each document before continuing.';
  FDescLbl.Color    := Pal.TextSecondary;
  FDescLbl.FontSize := 13;
  FDescLbl.Anchor(hpMiddle, hpMiddle);
  FDescLbl.Anchor(vpTop, vpTop, -(Pad + 34));
  FCard.InsertFront(FDescLbl);

  { Three document rows, stacked from Y = CardH - 96 downward }
  for I := 0 to 2 do
  begin
    YPos := CardH - 96 - I * (RowH + 6);

    Row        := TCastleRectangleControl.Create(FreeAtStop);
    Row.Color  := Pal.ContentBg;
    Row.Width  := CardW - Pad * 2;
    Row.Height := RowH;
    Row.Translation := Vector2(Pad, YPos);
    FCard.InsertFront(Row);
    FDocRow[I] := Row;

    Lbl          := TCastleLabel.Create(FreeAtStop);
    Lbl.Caption  := DocTitles[I];
    Lbl.Color    := Pal.TextPrimary;
    Lbl.FontSize := 14;
    Lbl.Anchor(hpLeft,   hpLeft,   10);
    Lbl.Anchor(vpMiddle, vpMiddle);
    Row.InsertFront(Lbl);
    FDocLabel[I] := Lbl;

    Btn          := TCastleButton.Create(FreeAtStop);
    Btn.Caption  := 'Read';
    Btn.FontSize := 13;
    Btn.Width    := BtnW;
    Btn.Anchor(hpRight,  hpRight,  -8);
    Btn.Anchor(vpMiddle, vpMiddle);
    Row.InsertFront(Btn);
    FDocBtn[I] := Btn;
  end;
  FDocBtn[0].OnClick := @ClickDoc0;
  FDocBtn[1].OnClick := @ClickDoc1;
  FDocBtn[2].OnClick := @ClickDoc2;

  { Agree / Decline buttons }
  FAgreeBtn          := TCastleButton.Create(FreeAtStop);
  FAgreeBtn.Caption  := 'Agree';
  FAgreeBtn.FontSize := 14;
  FAgreeBtn.Width    := 120;
  FAgreeBtn.Enabled  := False;
  FAgreeBtn.OnClick  := @ClickAgree;
  FAgreeBtn.Anchor(hpRight,  hpRight,  -(Pad + 130));
  FAgreeBtn.Anchor(vpBottom, vpBottom, Pad);
  FCard.InsertFront(FAgreeBtn);

  FDeclineBtn          := TCastleButton.Create(FreeAtStop);
  FDeclineBtn.Caption  := 'Decline';
  FDeclineBtn.FontSize := 14;
  FDeclineBtn.Width    := 110;
  FDeclineBtn.OnClick  := @ClickDecline;
  FDeclineBtn.Anchor(hpRight,  hpRight,  -Pad);
  FDeclineBtn.Anchor(vpBottom, vpBottom, Pad);
  FCard.InsertFront(FDeclineBtn);

  { ── Detail overlay ── }
  FDetailPanel        := TCastleRectangleControl.Create(FreeAtStop);
  FDetailPanel.Color  := Pal.PanelBg;
  FDetailPanel.FullSize := True;
  FDetailPanel.Exists   := False;
  FCard.InsertFront(FDetailPanel);

  FDetailTitle          := TCastleLabel.Create(FreeAtStop);
  FDetailTitle.Caption  := '';
  FDetailTitle.Color    := Pal.TextPrimary;
  FDetailTitle.FontSize := 16;
  FDetailTitle.Anchor(hpLeft, hpLeft, Pad);
  FDetailTitle.Anchor(vpTop,  vpTop,  -Pad);
  FDetailPanel.InsertFront(FDetailTitle);

  FDetailClose          := TCastleButton.Create(FreeAtStop);
  FDetailClose.Caption  := 'Back';
  FDetailClose.FontSize := 13;
  FDetailClose.Width    := 80;
  FDetailClose.OnClick  := @ClickClose;
  FDetailClose.Anchor(hpRight,  hpRight,  -Pad);
  FDetailClose.Anchor(vpTop,    vpTop,    -Pad);
  FDetailPanel.InsertFront(FDetailClose);

  FDetailScroll := TCastleScrollView.Create(FreeAtStop);
  FDetailScroll.Anchor(hpLeft,   hpLeft,   0);
  FDetailScroll.Anchor(hpRight,  hpRight,  0);
  FDetailScroll.Anchor(vpBottom, vpBottom, 0);
  FDetailScroll.Anchor(vpTop,    vpTop,    -60);
  FDetailPanel.InsertFront(FDetailScroll);

  FDetailText          := TCastleLabel.Create(FreeAtStop);
  FDetailText.Caption  := '';
  FDetailText.Color    := Pal.TextPrimary;
  FDetailText.FontSize := 12;
  FDetailText.Alignment := hpLeft;
  FDetailText.MaxWidth  := CardW - Pad * 2;
  FDetailText.Translation := Vector2(Pad, 0);
  FDetailScroll.ScrollArea.InsertFront(FDetailText);
end;

procedure TViewTerms.ShowList;
begin
  FDetailPanel.Exists := False;
end;

procedure TViewTerms.ShowDetail(DocIdx: Integer);
var
  TxtH : Single;
begin
  FDetailDocIdx       := DocIdx;
  FDetailTitle.Caption := DocTitles[DocIdx];
  FDetailText.Caption  := DocBody(DocIdx);
  FDetailText.MaxWidth := CardW - Pad * 2;

  { Size scroll area to the label height }
  TxtH := FDetailText.EffectiveHeight;
  if TxtH < FDetailScroll.Height then TxtH := FDetailScroll.Height;
  FDetailScroll.ScrollArea.Width  := CardW - Pad * 2;
  FDetailScroll.ScrollArea.Height := TxtH + Pad;
  FDetailText.Translation := Vector2(0, TxtH + Pad - FDetailText.EffectiveHeight);

  FDetailPanel.Exists := True;

  { Mark as read }
  FDocRead[DocIdx]         := True;
  FDocBtn[DocIdx].Caption  := 'Read ✓';
  UpdateAgreeButton;
end;

procedure TViewTerms.UpdateAgreeButton;
begin
  FAgreeBtn.Enabled := FDocRead[0] and FDocRead[1] and FDocRead[2];
end;

procedure TViewTerms.ClickDoc0(Sender: TObject);
begin ShowDetail(0); end;
procedure TViewTerms.ClickDoc1(Sender: TObject);
begin ShowDetail(1); end;
procedure TViewTerms.ClickDoc2(Sender: TObject);
begin ShowDetail(2); end;

procedure TViewTerms.ClickClose(Sender: TObject);
begin
  ShowList;
end;

procedure TViewTerms.ClickAgree(Sender: TObject);
begin
  SetTermsAccepted(True);
  LogInfo('Terms: user agreed');
  Container.View := ViewHome;
end;

procedure TViewTerms.ClickDecline(Sender: TObject);
begin
  LogInfo('Terms: user declined');
  Container.View := ViewLogin;
end;

procedure TViewTerms.Resize;
begin
  inherited;
  { Card is centred by anchors; nothing extra needed. }
end;

procedure TViewTerms.OnThemeChange;
begin
  if Container <> nil then
    Container.View := Self;
end;

end.
