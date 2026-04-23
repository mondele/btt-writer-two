{$mode objfpc}{$H+}
unit GameViewFeedback;

{ Feedback dialog view.

  Centered card with a text field for the user to describe a problem.
  Send logs the feedback locally (server submission is a future TODO).
  Cancel returns to the previous view.

  Reached via Container.PushView(ViewFeedback) from Home or Editor. }

interface

uses
  Classes,
  CastleUIControls, CastleControls, CastleColors,
  CGEViewBase;

type
  TViewFeedback = class(TCGEViewBase)
  private
    FCard        : TCastleRectangleControl;
    FWarningLbl  : TCastleLabel;
    FFeedbackEdit: TCastleEdit;
    FSendBtn     : TCastleButton;
    FCancelBtn   : TCastleButton;
    FStatusLbl   : TCastleLabel;

    procedure BuildChrome;
    procedure ClickSend(Sender: TObject);
    procedure ClickCancel(Sender: TObject);
  public
    procedure Start; override;
    procedure OnThemeChange; override;
  end;

var
  ViewFeedback: TViewFeedback;

implementation

uses
  SysUtils, CastleVectors,
  BTTTheme, AppLog;

const
  CardW = 480;
  CardH = 280;
  Pad   = 28;
  EditW = CardW - Pad * 2;

procedure TViewFeedback.Start;
begin
  inherited;
  ApplyBackground;
  BuildChrome;
end;

procedure TViewFeedback.BuildChrome;
var
  Pal      : TBTTPalette;
  TitleLbl : TCastleLabel;
begin
  Pal := P;

  FCard       := TCastleRectangleControl.Create(FreeAtStop);
  FCard.Color := Pal.PanelBg;
  FCard.Width  := CardW;
  FCard.Height := CardH;
  FCard.Anchor(hpMiddle, hpMiddle);
  FCard.Anchor(vpMiddle, vpMiddle);
  InsertFront(FCard);

  TitleLbl          := TCastleLabel.Create(FreeAtStop);
  TitleLbl.Caption  := 'Feedback';
  TitleLbl.Color    := Pal.TextPrimary;
  TitleLbl.FontSize := 20;
  TitleLbl.Anchor(hpMiddle, hpMiddle);
  TitleLbl.Anchor(vpTop, vpTop, -Pad);
  FCard.InsertFront(TitleLbl);

  FWarningLbl          := TCastleLabel.Create(FreeAtStop);
  FWarningLbl.Caption  := 'Describe the problem you are experiencing:';
  FWarningLbl.Color    := Pal.TextSecondary;
  FWarningLbl.FontSize := 13;
  FWarningLbl.Anchor(hpLeft, hpLeft, Pad);
  FWarningLbl.Anchor(vpTop, vpTop, -(Pad + 36));
  FCard.InsertFront(FWarningLbl);

  FFeedbackEdit             := TCastleEdit.Create(FreeAtStop);
  FFeedbackEdit.Placeholder := 'Enter your feedback here...';
  FFeedbackEdit.Width       := EditW;
  FFeedbackEdit.FontSize    := 14;
  FFeedbackEdit.Anchor(hpMiddle, hpMiddle);
  FFeedbackEdit.Anchor(vpMiddle, vpMiddle, 20);
  FCard.InsertFront(FFeedbackEdit);

  FStatusLbl          := TCastleLabel.Create(FreeAtStop);
  FStatusLbl.Caption  := '';
  FStatusLbl.Color    := Vector4(0.3, 0.65, 0.3, 1);
  FStatusLbl.FontSize := 13;
  FStatusLbl.Anchor(hpMiddle, hpMiddle);
  FStatusLbl.Anchor(vpMiddle, vpMiddle, -18);
  FStatusLbl.Exists   := False;
  FCard.InsertFront(FStatusLbl);

  FSendBtn          := TCastleButton.Create(FreeAtStop);
  FSendBtn.Caption  := 'Send';
  FSendBtn.FontSize := 14;
  FSendBtn.Width    := 100;
  FSendBtn.OnClick  := @ClickSend;
  FSendBtn.Anchor(hpRight, hpRight, -Pad);
  FSendBtn.Anchor(vpBottom, vpBottom, Pad);
  FCard.InsertFront(FSendBtn);

  FCancelBtn          := TCastleButton.Create(FreeAtStop);
  FCancelBtn.Caption  := 'Cancel';
  FCancelBtn.FontSize := 14;
  FCancelBtn.Width    := 100;
  FCancelBtn.OnClick  := @ClickCancel;
  FCancelBtn.Anchor(hpRight, hpRight, -(Pad + 110));
  FCancelBtn.Anchor(vpBottom, vpBottom, Pad);
  FCard.InsertFront(FCancelBtn);
end;

procedure TViewFeedback.ClickSend(Sender: TObject);
var
  Text: string;
begin
  Text := Trim(FFeedbackEdit.Text);
  if Text = '' then
  begin
    FStatusLbl.Caption := 'Please enter a message before sending.';
    FStatusLbl.Color   := Vector4(0.85, 0.2, 0.2, 1);
    FStatusLbl.Exists  := True;
    Exit;
  end;
  LogFmt(llInfo, 'User feedback: %s', [Text]);
  FStatusLbl.Caption := 'Thank you! Your feedback has been recorded.';
  FStatusLbl.Color   := Vector4(0.3, 0.65, 0.3, 1);
  FStatusLbl.Exists  := True;
  FSendBtn.Enabled   := False;
  FFeedbackEdit.Text := '';
end;

procedure TViewFeedback.ClickCancel(Sender: TObject);
begin
  Container.PopView(Self);
end;

procedure TViewFeedback.OnThemeChange;
begin
  if Container <> nil then
    Container.View := Self;
end;

end.
