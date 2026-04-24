{$mode objfpc}{$H+}
unit GameViewFeedback;

{ Feedback dialog view.

  Compact centered card matching v1 feedback-form-en.png: title,
  internet-connection subtitle, hairline separator, text input area,
  and CANCEL / SEND text-links at the bottom-right.

  Send logs the feedback locally (server submission is a future TODO).
  Cancel pops the view.

  Reached via Container.PushView(ViewFeedback) from Home or Editor. }

interface

uses
  Classes,
  CastleUIControls, CastleControls, CastleColors,
  CGEViewBase, BTTHeader, BTTBreadcrumb, BTTStatusBar, BTTTheme;

type
  TViewFeedback = class(TCGEViewBase)
  private
    FHeader      : TBTTHeader;
    FCrumb       : TBTTBreadcrumb;
    FStatusBar   : TBTTStatusBar;
    FCard        : TCastleRectangleControl;
    FTitleLbl    : TCastleLabel;
    FNetLbl      : TCastleLabel;
    FSeparator   : TCastleRectangleControl;
    FFeedbackEdit: TCastleEdit;
    FSendBtn     : TCastleButton;
    FCancelBtn   : TCastleButton;
    FStatusLbl   : TCastleLabel;

    procedure BuildChrome;
    procedure StyleLink(Btn: TCastleButton; const Pal: TBTTPalette; EmphAccent: Boolean);
    procedure ClickSend(Sender: TObject);
    procedure ClickCancel(Sender: TObject);
  public
    procedure Start; override;
    procedure Resize; override;
    procedure OnThemeChange; override;
  end;

var
  ViewFeedback: TViewFeedback;

implementation

uses
  SysUtils, CastleVectors,
  AppLog, CGEStrings;

const
  CardW = 560;
  CardH = 360;
  Pad   = 28;
  SepH  = 1;

procedure TViewFeedback.Start;
begin
  inherited;
  ApplyBackground;
  BuildChrome;
end;

procedure TViewFeedback.StyleLink(Btn: TCastleButton; const Pal: TBTTPalette;
  EmphAccent: Boolean);
begin
  Btn.CustomBackground    := True;
  Btn.CustomColorNormal   := Vector4(0, 0, 0, 0);
  Btn.CustomColorFocused  := Vector4(0, 0, 0, 0.05);
  Btn.CustomColorPressed  := Vector4(0, 0, 0, 0.10);
  Btn.CustomColorDisabled := Vector4(0, 0, 0, 0);
  Btn.CustomTextColorUse  := True;
  if EmphAccent then
    Btn.CustomTextColor := Pal.Primary
  else
    Btn.CustomTextColor := Pal.TextSecondary;
end;

procedure TViewFeedback.BuildChrome;
var
  Pal : TBTTPalette;
begin
  Pal := P;

  FHeader := TBTTHeader.Create(FreeAtStop, Pal);
  FHeader.SetTitle(rsAppName);
  InsertFront(FHeader);

  FCrumb := TBTTBreadcrumb.Create(FreeAtStop, Pal);
  FCrumb.OnBack := @ClickCancel;
  FCrumb.SetCrumbs([rsNewProjCrumbHome, rsFeedbackCrumb]);
  InsertFront(FCrumb);

  FStatusBar := TBTTStatusBar.Create(FreeAtStop, Pal);
  InsertFront(FStatusBar);

  { Centred card. }
  FCard       := TCastleRectangleControl.Create(FreeAtStop);
  FCard.Color := Pal.PanelBg;
  FCard.Width  := CardW;
  FCard.Height := CardH;
  FCard.Anchor(hpMiddle, hpMiddle);
  FCard.Anchor(vpMiddle, vpMiddle);
  InsertFront(FCard);

  { Title — centred at top. }
  FTitleLbl          := TCastleLabel.Create(FreeAtStop);
  FTitleLbl.Caption  := rsFeedbackHeading;
  FTitleLbl.Color    := Pal.TextPrimary;
  FTitleLbl.FontSize := 20;
  FTitleLbl.Alignment := hpMiddle;
  FTitleLbl.Anchor(hpMiddle, hpMiddle);
  FTitleLbl.Anchor(vpTop, vpTop, -22);
  FCard.InsertFront(FTitleLbl);

  { "This will use your internet connection" — centred subtitle. }
  FNetLbl          := TCastleLabel.Create(FreeAtStop);
  FNetLbl.Caption  := #$E2#$9F#$B3 + '  ' + rsFeedbackNetWarning;
  FNetLbl.Color    := Pal.TextPrimary;
  FNetLbl.FontSize := 13;
  FNetLbl.Alignment := hpMiddle;
  FNetLbl.Anchor(hpMiddle, hpMiddle);
  FNetLbl.Anchor(vpTop, vpTop, -54);
  FCard.InsertFront(FNetLbl);

  { Hairline separator. }
  FSeparator        := TCastleRectangleControl.Create(FreeAtStop);
  FSeparator.Color  := Pal.Border;
  FSeparator.Height := SepH;
  FSeparator.Anchor(hpLeft,  hpLeft,  0);
  FSeparator.Anchor(vpTop,   vpTop,   -86);
  FCard.InsertFront(FSeparator);

  { Input field — single-line (CGE limitation); see rsFeedbackPlaceholder.
    Size set in Resize so it stretches card-wide. }
  FFeedbackEdit             := TCastleEdit.Create(FreeAtStop);
  FFeedbackEdit.Placeholder := rsFeedbackPlaceholder;
  FFeedbackEdit.FontSize    := 15;
  FFeedbackEdit.Anchor(hpLeft, hpLeft, Pad);
  FFeedbackEdit.Anchor(vpTop,  vpTop,  -108);
  FCard.InsertFront(FFeedbackEdit);

  { Inline status message (empty / error / success). }
  FStatusLbl          := TCastleLabel.Create(FreeAtStop);
  FStatusLbl.Caption  := '';
  FStatusLbl.Color    := Vector4(0.3, 0.65, 0.3, 1);
  FStatusLbl.FontSize := 13;
  FStatusLbl.Anchor(hpLeft, hpLeft, Pad);
  FStatusLbl.Anchor(vpBottom, vpBottom, 58);
  FStatusLbl.Exists   := False;
  FCard.InsertFront(FStatusLbl);

  { CANCEL + SEND as text-link buttons at bottom-right. }
  FCancelBtn          := TCastleButton.Create(FreeAtStop);
  FCancelBtn.Caption  := rsFeedbackCancel;
  FCancelBtn.FontSize := 14;
  FCancelBtn.OnClick  := @ClickCancel;
  StyleLink(FCancelBtn, Pal, False);
  FCancelBtn.Anchor(hpRight,  hpRight,  -(Pad + 90));
  FCancelBtn.Anchor(vpBottom, vpBottom, 18);
  FCard.InsertFront(FCancelBtn);

  FSendBtn          := TCastleButton.Create(FreeAtStop);
  FSendBtn.Caption  := rsFeedbackSend;
  FSendBtn.FontSize := 14;
  FSendBtn.OnClick  := @ClickSend;
  StyleLink(FSendBtn, Pal, True);
  FSendBtn.Anchor(hpRight,  hpRight,  -Pad);
  FSendBtn.Anchor(vpBottom, vpBottom, 18);
  FCard.InsertFront(FSendBtn);
end;

procedure TViewFeedback.ClickSend(Sender: TObject);
var
  Text: string;
begin
  Text := Trim(FFeedbackEdit.Text);
  if Text = '' then
  begin
    FStatusLbl.Caption := rsFeedbackEmpty;
    FStatusLbl.Color   := Vector4(0.85, 0.2, 0.2, 1);
    FStatusLbl.Exists  := True;
    Exit;
  end;
  LogFmt(llInfo, 'User feedback: %s', [Text]);
  FStatusLbl.Caption := rsFeedbackSent;
  FStatusLbl.Color   := Vector4(0.3, 0.65, 0.3, 1);
  FStatusLbl.Exists  := True;
  FSendBtn.Enabled   := False;
  FFeedbackEdit.Text := '';
end;

procedure TViewFeedback.ClickCancel(Sender: TObject);
begin
  Container.PopView(Self);
end;

procedure TViewFeedback.Resize;
var
  W, H: Single;
begin
  inherited;
  if FHeader = nil then Exit;
  W := EffectiveWidth;
  H := EffectiveHeight;

  FHeader.Translation := CastleVectors.Vector2(0, H - BTT_HEADER_H);
  FHeader.Width       := W;
  FHeader.Height      := BTT_HEADER_H;

  FCrumb.Translation := CastleVectors.Vector2(0, H - BTT_HEADER_H - BTT_BREADCRUMB_H);
  FCrumb.Width       := W;
  FCrumb.Height      := BTT_BREADCRUMB_H;

  FStatusBar.Translation := CastleVectors.Vector2(0, 0);
  FStatusBar.Width       := W;
  FStatusBar.Height      := BTT_STATUS_H;

  { Stretch the separator and input to the card's width. }
  if FSeparator <> nil then
    FSeparator.Width := FCard.EffectiveWidth;
  if FFeedbackEdit <> nil then
    FFeedbackEdit.Width := FCard.EffectiveWidth - Pad * 2;
end;

procedure TViewFeedback.OnThemeChange;
begin
  if Container <> nil then
    Container.View := Self;
end;

end.
