{$mode objfpc}{$H+}
unit GameViewFeedback;

{ Feedback dialog view.

  Card layout loaded from castle-data:/designs/feedback.castle-user-interface.
  Chrome (header, breadcrumb, status bar) still built in code — they are
  custom components (TBTTHeader etc.) not yet registered as serializable.

  Pilot of designer-first workflow. See README / migration plan. }

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
    procedure LoadCard;
    procedure ApplyPalette;
    procedure StyleLink(Btn: TCastleButton; EmphAccent: Boolean);
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
  SysUtils, CastleVectors, CastleComponentSerialize,
  AppLog, CGEStrings;

const
  Pad  = 28;

procedure TViewFeedback.Start;
begin
  inherited;
  ApplyBackground;
  BuildChrome;
  LoadCard;
  ApplyPalette;
end;

procedure TViewFeedback.BuildChrome;
var
  Pal: TBTTPalette;
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
end;

procedure TViewFeedback.LoadCard;
begin
  FCard := ComponentLoad(
    'castle-data:/designs/feedback.castle-user-interface',
    FreeAtStop) as TCastleRectangleControl;
  InsertFront(FCard);

  FTitleLbl     := FreeAtStop.FindRequiredComponent('TitleLbl')    as TCastleLabel;
  FNetLbl       := FreeAtStop.FindRequiredComponent('NetLbl')      as TCastleLabel;
  FSeparator    := FreeAtStop.FindRequiredComponent('Separator')   as TCastleRectangleControl;
  FFeedbackEdit := FreeAtStop.FindRequiredComponent('FeedbackEdit') as TCastleEdit;
  FStatusLbl    := FreeAtStop.FindRequiredComponent('StatusLbl')   as TCastleLabel;
  FCancelBtn    := FreeAtStop.FindRequiredComponent('CancelBtn')   as TCastleButton;
  FSendBtn      := FreeAtStop.FindRequiredComponent('SendBtn')     as TCastleButton;

  { Localised captions — designer file carries English defaults. }
  FTitleLbl.Caption    := rsFeedbackHeading;
  FNetLbl.Caption      := #$E2#$9F#$B3 + '  ' + rsFeedbackNetWarning;
  FFeedbackEdit.Placeholder := rsFeedbackPlaceholder;
  FCancelBtn.Caption   := rsFeedbackCancel;
  FSendBtn.Caption     := rsFeedbackSend;

  FCancelBtn.OnClick := @ClickCancel;
  FSendBtn.OnClick   := @ClickSend;
end;

procedure TViewFeedback.ApplyPalette;
var
  Pal: TBTTPalette;
begin
  Pal := P;
  FCard.Color       := Pal.PanelBg;
  FTitleLbl.Color   := Pal.TextPrimary;
  FNetLbl.Color     := Pal.TextPrimary;
  FSeparator.Color  := Pal.Border;
  FStatusLbl.Color  := Vector4(0.3, 0.65, 0.3, 1);
  StyleLink(FCancelBtn, False);
  StyleLink(FSendBtn,   True);
end;

procedure TViewFeedback.StyleLink(Btn: TCastleButton; EmphAccent: Boolean);
var
  Pal: TBTTPalette;
begin
  Pal := P;
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

  if FFeedbackEdit <> nil then
    FFeedbackEdit.Width := FCard.EffectiveWidth - Pad * 2;
end;

procedure TViewFeedback.OnThemeChange;
begin
  if FCard <> nil then
    ApplyPalette;
  if Container <> nil then
    Container.View := Self;
end;

end.
