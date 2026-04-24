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
  CGEViewBase, BTTHeader, BTTBreadcrumb, BTTStatusBar;

type
  TViewTerms = class(TCGEViewBase)
  private
    FHeader      : TBTTHeader;
    FCrumb       : TBTTBreadcrumb;
    FStatusBar   : TBTTStatusBar;
    FCard        : TCastleRectangleControl;
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
  LegalTexts, CGEStrings,
  GameViewHome, GameViewLogin;

const
  Pad      = 32;
  RowH     = 52;
  RowGap   = 14;

{ Document titles — resolved at call time so language changes take effect. }
function DocTitle(Idx: Integer): string;
begin
  case Idx of
    0: Result := rsTermsLicenseAgreement;
    1: Result := rsTermsTranslationGuide;
    2: Result := rsTermsStatementOfFaith;
  else
    Result := '';
  end;
end;

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
  Btn  : TCastleButton;
  YPos : Single;
begin
  Pal := P;

  FHeader := TBTTHeader.Create(FreeAtStop, Pal);
  FHeader.SetTitle(rsAppName);
  InsertFront(FHeader);

  FCrumb := TBTTBreadcrumb.Create(FreeAtStop, Pal);
  FCrumb.SetCrumbs([rsTermsCrumb]);
  InsertFront(FCrumb);

  FStatusBar := TBTTStatusBar.Create(FreeAtStop, Pal);
  InsertFront(FStatusBar);

  { ── Full-bleed white panel below the chrome ── }
  FCard        := TCastleRectangleControl.Create(FreeAtStop);
  FCard.Color  := Pal.PanelBg;
  { Size and position set in Resize to fill content area. }
  InsertFront(FCard);

  { Description paragraph at top }
  FDescLbl          := TCastleLabel.Create(FreeAtStop);
  FDescLbl.Caption  := rsTermsIntro;
  FDescLbl.Color     := Pal.TextPrimary;
  FDescLbl.FontSize  := 14;
  FDescLbl.Alignment := hpMiddle;
  FDescLbl.Anchor(hpMiddle, hpMiddle);
  FDescLbl.Anchor(vpTop, vpTop, -Pad);
  FCard.InsertFront(FDescLbl);

  { Three full-width solid-green document buttons, stacked. Width set in Resize. }
  for I := 0 to 2 do
  begin
    YPos := -(Pad + 80 + I * (RowH + RowGap));  { offset below description }

    Btn              := TCastleButton.Create(FreeAtStop);
    Btn.Caption      := UpperCase(DocTitle(I));
    Btn.FontSize     := 15;
    Btn.AutoSize     := False;
    Btn.Height       := RowH;
    Btn.CustomBackground    := True;
    Btn.CustomColorNormal   := Pal.Accent;
    Btn.CustomColorFocused  := Pal.Accent;
    Btn.CustomColorPressed  := Pal.Accent;
    Btn.CustomTextColorUse  := True;
    Btn.CustomTextColor     := Pal.TextInverse;
    Btn.Anchor(hpLeft, hpLeft, Pad);
    Btn.Anchor(vpTop,  vpTop,  YPos);
    FCard.InsertFront(Btn);
    FDocBtn[I]   := Btn;
    FDocLabel[I] := nil;
    FDocRow[I]   := nil;
  end;
  FDocBtn[0].OnClick := @ClickDoc0;
  FDocBtn[1].OnClick := @ClickDoc1;
  FDocBtn[2].OnClick := @ClickDoc2;

  { Bottom row — NO THANKS (left-ish) / I AGREE (right-ish), as text-link buttons }
  FDeclineBtn          := TCastleButton.Create(FreeAtStop);
  FDeclineBtn.Caption  := rsTermsNoThanks;
  FDeclineBtn.FontSize := 14;
  FDeclineBtn.OnClick  := @ClickDecline;
  FDeclineBtn.CustomBackground   := True;
  FDeclineBtn.CustomColorNormal  := Vector4(0, 0, 0, 0);
  FDeclineBtn.CustomColorFocused := Vector4(0, 0, 0, 0.05);
  FDeclineBtn.CustomColorPressed := Vector4(0, 0, 0, 0.10);
  FDeclineBtn.CustomTextColorUse := True;
  FDeclineBtn.CustomTextColor    := Pal.TextSecondary;
  FDeclineBtn.Anchor(hpLeft,  hpLeft,  Pad * 3);
  FDeclineBtn.Anchor(vpBottom, vpBottom, Pad);
  FCard.InsertFront(FDeclineBtn);

  FAgreeBtn          := TCastleButton.Create(FreeAtStop);
  FAgreeBtn.Caption  := rsTermsAgree;
  FAgreeBtn.FontSize := 14;
  FAgreeBtn.Enabled  := False;
  FAgreeBtn.OnClick  := @ClickAgree;
  FAgreeBtn.CustomBackground    := True;
  FAgreeBtn.CustomColorNormal   := Vector4(0, 0, 0, 0);
  FAgreeBtn.CustomColorFocused  := Vector4(0, 0, 0, 0.05);
  FAgreeBtn.CustomColorPressed  := Vector4(0, 0, 0, 0.10);
  FAgreeBtn.CustomColorDisabled := Vector4(0, 0, 0, 0);
  FAgreeBtn.CustomTextColorUse  := True;
  FAgreeBtn.CustomTextColor     := Pal.TextMuted;
  FAgreeBtn.Anchor(hpRight, hpRight, -(Pad * 3));
  FAgreeBtn.Anchor(vpBottom, vpBottom, Pad);
  FCard.InsertFront(FAgreeBtn);

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
  FDetailText.MaxWidth  := 800;
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
  FDetailTitle.Caption := DocTitle(DocIdx);
  FDetailText.Caption  := DocBody(DocIdx);
  FDetailText.MaxWidth := 800;

  { Size scroll area to the label height }
  TxtH := FDetailText.EffectiveHeight;
  if TxtH < FDetailScroll.Height then TxtH := FDetailScroll.Height;
  FDetailScroll.ScrollArea.Width  := 800;
  FDetailScroll.ScrollArea.Height := TxtH + Pad;
  FDetailText.Translation := Vector2(0, TxtH + Pad - FDetailText.EffectiveHeight);

  FDetailPanel.Exists := True;

  { Mark as read — no visual change to the button itself (v1 doesn't show a "read" tick). }
  FDocRead[DocIdx] := True;
  UpdateAgreeButton;
end;

procedure TViewTerms.UpdateAgreeButton;
var
  Pal: TBTTPalette;
  AllRead: Boolean;
begin
  Pal := P;
  AllRead := FDocRead[0] and FDocRead[1] and FDocRead[2];
  FAgreeBtn.Enabled := AllRead;
  if AllRead then
    FAgreeBtn.CustomTextColor := Pal.Accent
  else
    FAgreeBtn.CustomTextColor := Pal.TextMuted;
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
var
  W, H, CardH: Single;
  I: Integer;
begin
  inherited;
  if FHeader = nil then Exit;
  W := EffectiveWidth;
  H := EffectiveHeight;

  FHeader.Translation := Vector2(0, H - BTT_HEADER_H);
  FHeader.Width       := W;
  FHeader.Height      := BTT_HEADER_H;

  FCrumb.Translation := Vector2(0, H - BTT_HEADER_H - BTT_BREADCRUMB_H);
  FCrumb.Width       := W;
  FCrumb.Height      := BTT_BREADCRUMB_H;

  FStatusBar.Translation := Vector2(0, 0);
  FStatusBar.Width       := W;
  FStatusBar.Height      := BTT_STATUS_H;

  { Full-bleed card fills the area between breadcrumb and status bar. }
  CardH := H - BTT_HEADER_H - BTT_BREADCRUMB_H - BTT_STATUS_H;
  FCard.Translation := Vector2(0, BTT_STATUS_H);
  FCard.Width       := W;
  FCard.Height      := CardH;

  { Doc buttons: full-width within the card. }
  for I := 0 to 2 do
    if FDocBtn[I] <> nil then
      FDocBtn[I].Width := W - Pad * 2;
end;

procedure TViewTerms.OnThemeChange;
begin
  if Container <> nil then
    Container.View := Self;
end;

end.
