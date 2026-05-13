{$mode objfpc}{$H+}
unit GameViewTerms;

{ Terms of Use screen.

  Card layout loaded from castle-data:/designs/terms.castle-user-interface.
  Chrome (header, breadcrumb, status bar) still built in code; Resize wires
  card geometry, button widths, and detail-scroll size.

  Shown after login when terms have not yet been accepted. Three documents
  (License, Guidelines, Statement of Faith). Agree enables once all three
  are opened. }

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

    FDocBtn      : array[0..2] of TCastleButton;
    FDocRead     : array[0..2] of Boolean;

    FAgreeBtn    : TCastleButton;
    FDeclineBtn  : TCastleButton;

    FDetailPanel : TCastleRectangleControl;
    FDetailTitle : TCastleLabel;
    FDetailScroll: TCastleScrollView;
    FDetailText  : TCastleLabel;
    FDetailClose : TCastleButton;
    FDetailDocIdx: Integer;

    procedure BuildChrome;
    procedure LoadCard;
    procedure ApplyPalette;
    procedure StyleLink(Btn: TCastleButton; EmphasisEnabled: Boolean);
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
  SysUtils, CastleVectors, CastleComponentSerialize,
  AppSettings, AppLog, BTTTheme,
  LegalTexts, CGEStrings,
  GameViewHome, GameViewLogin;

const
  Pad = 32;

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
  LoadCard;
  ApplyPalette;
  ShowList;
end;

procedure TViewTerms.BuildChrome;
var
  Pal: TBTTPalette;
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
end;

procedure TViewTerms.LoadCard;
var
  I: Integer;
begin
  FCard := ComponentLoad(
    'castle-data:/designs/terms.castle-user-interface',
    FreeAtStop) as TCastleRectangleControl;
  InsertFront(FCard);

  FDescLbl      := FreeAtStop.FindRequiredComponent('DescLbl')      as TCastleLabel;
  FDocBtn[0]    := FreeAtStop.FindRequiredComponent('DocBtn0')      as TCastleButton;
  FDocBtn[1]    := FreeAtStop.FindRequiredComponent('DocBtn1')      as TCastleButton;
  FDocBtn[2]    := FreeAtStop.FindRequiredComponent('DocBtn2')      as TCastleButton;
  FDeclineBtn   := FreeAtStop.FindRequiredComponent('DeclineBtn')   as TCastleButton;
  FAgreeBtn     := FreeAtStop.FindRequiredComponent('AgreeBtn')     as TCastleButton;
  FDetailPanel  := FreeAtStop.FindRequiredComponent('DetailPanel')  as TCastleRectangleControl;
  FDetailTitle  := FreeAtStop.FindRequiredComponent('DetailTitle')  as TCastleLabel;
  FDetailClose  := FreeAtStop.FindRequiredComponent('DetailClose')  as TCastleButton;
  FDetailScroll := FreeAtStop.FindRequiredComponent('DetailScroll') as TCastleScrollView;
  FDetailText   := FreeAtStop.FindRequiredComponent('DetailText')   as TCastleLabel;

  FDescLbl.Caption := rsTermsIntro;
  for I := 0 to 2 do
    FDocBtn[I].Caption := UpperCase(DocTitle(I));
  FDeclineBtn.Caption  := rsTermsNoThanks;
  FAgreeBtn.Caption    := rsTermsAgree;
  FDetailClose.Caption := rsCommonBack;

  FDocBtn[0].OnClick   := @ClickDoc0;
  FDocBtn[1].OnClick   := @ClickDoc1;
  FDocBtn[2].OnClick   := @ClickDoc2;
  FDeclineBtn.OnClick  := @ClickDecline;
  FAgreeBtn.OnClick    := @ClickAgree;
  FDetailClose.OnClick := @ClickClose;

  FDetailText.Translation := Vector2(Pad, 0);
end;

procedure TViewTerms.ApplyPalette;
var
  Pal: TBTTPalette;
  I: Integer;
begin
  Pal := P;
  FCard.Color         := Pal.PanelBg;
  FDescLbl.Color      := Pal.TextPrimary;
  FDetailPanel.Color  := Pal.PanelBg;
  FDetailTitle.Color  := Pal.TextPrimary;
  FDetailText.Color   := Pal.TextPrimary;

  for I := 0 to 2 do
  begin
    FDocBtn[I].CustomColorNormal  := Pal.Accent;
    FDocBtn[I].CustomColorFocused := Pal.Accent;
    FDocBtn[I].CustomColorPressed := Pal.Accent;
    FDocBtn[I].CustomTextColor    := Pal.TextInverse;
  end;

  StyleLink(FDeclineBtn, True);
  StyleLink(FAgreeBtn,   FAgreeBtn.Enabled);
end;

procedure TViewTerms.StyleLink(Btn: TCastleButton; EmphasisEnabled: Boolean);
var
  Pal: TBTTPalette;
begin
  Pal := P;
  Btn.CustomColorNormal   := Vector4(0, 0, 0, 0);
  Btn.CustomColorFocused  := Vector4(0, 0, 0, 0.05);
  Btn.CustomColorPressed  := Vector4(0, 0, 0, 0.10);
  Btn.CustomColorDisabled := Vector4(0, 0, 0, 0);
  if EmphasisEnabled then
    Btn.CustomTextColor := Pal.Accent
  else
    Btn.CustomTextColor := Pal.TextSecondary;
end;

procedure TViewTerms.ShowList;
begin
  FDetailPanel.Exists := False;
end;

procedure TViewTerms.ShowDetail(DocIdx: Integer);
var
  TxtH, AreaW: Single;
begin
  FDetailDocIdx        := DocIdx;
  FDetailTitle.Caption := DocTitle(DocIdx);
  FDetailText.Caption  := DocBody(DocIdx);

  AreaW := FDetailScroll.EffectiveWidthForChildren - FDetailScroll.EffectiveScrollBarWidth;
  if AreaW < 100 then AreaW := FDetailScroll.Width - 24;
  FDetailText.MaxWidth := AreaW - Pad * 2;

  TxtH := FDetailText.EffectiveHeight;
  if TxtH < FDetailScroll.Height then TxtH := FDetailScroll.Height;
  FDetailScroll.ScrollArea.Width  := AreaW;
  FDetailScroll.ScrollArea.Height := TxtH + Pad;
  FDetailText.Translation := Vector2(Pad, TxtH + Pad - FDetailText.EffectiveHeight);

  FDetailPanel.Exists := True;

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

procedure TViewTerms.ClickDoc0(Sender: TObject); begin ShowDetail(0); end;
procedure TViewTerms.ClickDoc1(Sender: TObject); begin ShowDetail(1); end;
procedure TViewTerms.ClickDoc2(Sender: TObject); begin ShowDetail(2); end;

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

  CardH := H - BTT_HEADER_H - BTT_BREADCRUMB_H - BTT_STATUS_H;
  FCard.Translation := Vector2(0, BTT_STATUS_H);
  FCard.Width       := W;
  FCard.Height      := CardH;

  for I := 0 to 2 do
    if FDocBtn[I] <> nil then
      FDocBtn[I].Width := W - Pad * 2;

  if FDetailScroll <> nil then
  begin
    FDetailScroll.Width  := W;
    FDetailScroll.Height := CardH - 60;
  end;
end;

procedure TViewTerms.OnThemeChange;
begin
  if FCard <> nil then
    ApplyPalette;
  if Container <> nil then
    Container.View := Self;
end;

end.
