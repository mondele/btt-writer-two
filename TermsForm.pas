unit TermsForm;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Forms, Controls, StdCtrls, ExtCtrls, Graphics, Dialogs,
  LCLIntf, LResources, Themes, LegalTexts, AppSettings, ThemePalette, AppLog;

function ShowTermsDialog: Boolean;

implementation

resourcestring
  rsTermsTitle = 'Terms of Use';
  rsTermsPrompt = 'Please review and accept the following:';
  rsLicenseBtn = 'License Agreement';
  rsGuidelinesBtn = 'Translation Guidelines';
  rsFaithBtn = 'Statement of Faith';
  rsAgreeBtn = 'Agree';
  rsDeclineBtn = 'Decline';

type
  { Simple text viewer dialog }
  TTextViewerForm = class(TForm)
  private
  public
    constructor CreateWithText(AOwner: TComponent; const ATitle, AText: string);
  end;

  TTermsForm = class(TForm)
  private
    FViewedLicense, FViewedGuidelines, FViewedFaith: Boolean;
    procedure LicenseBtnClick(Sender: TObject);
    procedure GuidelinesBtnClick(Sender: TObject);
    procedure FaithBtnClick(Sender: TObject);
    procedure AgreeBtnClick(Sender: TObject);
  end;

constructor TTextViewerForm.CreateWithText(AOwner: TComponent; const ATitle, AText: string);
var
  Memo: TMemo;
  BtnOK: TButton;
  Pal: TThemePalette;
begin
  inherited CreateNew(AOwner);
  Pal := GetThemePalette(GetEffectiveTheme);

  Position := poScreenCenter;
  BorderStyle := bsSingle;
  BorderIcons := [biSystemMenu];
  Caption := ATitle;
  Width := 700;
  Height := 500;
  Color := Pal.PanelBg;
  KeyPreview := True;

  Memo := TMemo.Create(Self);
  Memo.Parent := Self;
  Memo.Align := alClient;
  Memo.ReadOnly := True;
  Memo.WordWrap := True;
  Memo.ScrollBars := ssBoth;
  Memo.Font.Name := 'Roboto Mono';
  Memo.Font.Height := -12;
  Memo.Color := Pal.Surface;
  Memo.Font.Color := Pal.TextPrimary;
  Memo.Lines.Text := AText;

  BtnOK := TButton.Create(Self);
  BtnOK.Parent := Self;
  BtnOK.Align := alBottom;
  BtnOK.Height := 36;
  BtnOK.Caption := 'OK';
  BtnOK.ModalResult := mrOK;
  BtnOK.Default := True;
end;

procedure TTermsForm.LicenseBtnClick(Sender: TObject);
begin
  FViewedLicense := True;
  with TTextViewerForm.Create(Self, rsLicenseTitle, rsLicenseAgreement) do
    ShowModal;
end;

procedure TTermsForm.GuidelinesBtnClick(Sender: TObject);
begin
  FViewedGuidelines := True;
  with TTextViewerForm.Create(Self, rsGuidelinesTitle, rsTranslationGuidelines) do
    ShowModal;
end;

procedure TTermsForm.FaithBtnClick(Sender: TObject);
begin
  FViewedFaith := True;
  with TTextViewerForm.Create(Self, rsStatementTitle, rsStatementOfFaith) do
    ShowModal;
end;

procedure TTermsForm.AgreeBtnClick(Sender: TObject);
begin
  if FViewedLicense and FViewedGuidelines and FViewedFaith then
    ModalResult := mrOK
  else
    ShowMessage('Please review all three documents before agreeing.');
end;

function ShowTermsDialog: Boolean;
var
  F: TTermsForm;
  Pal: TThemePalette;
  lblPrompt: TLabel;
  pnlLicense, pnlGuidelines, pnlFaith: TPanel;
  lblLicense, lblGuidelines, lblFaith: TLabel;
  btnAgree, btnDecline: TButton;
  YPos: Integer;
begin
  Result := False;
  Pal := GetThemePalette(GetEffectiveTheme);

  F := TTermsForm.CreateNew(nil);
  try
    F.Position := poScreenCenter;
    F.BorderStyle := bsSingle;
    F.Caption := rsTermsTitle;
    F.Width := 500;
    F.Height := 420;
    F.Color := Pal.PanelBg;

    lblPrompt := TLabel.Create(F);
    lblPrompt.Parent := F;
    lblPrompt.SetBounds(24, 12, 452, 32);
    lblPrompt.Font.Height := -14;
    lblPrompt.Font.Style := [fsBold];
    lblPrompt.Font.Color := Pal.TextPrimary;
    lblPrompt.Caption := rsTermsPrompt;
    lblPrompt.WordWrap := True;

    YPos := 52;

    { License }
    pnlLicense := TPanel.Create(F);
    pnlLicense.Parent := F;
    pnlLicense.SetBounds(24, YPos, 452, 48);
    pnlLicense.BevelOuter := bvNone;
    pnlLicense.Color := Pal.Accent;
    pnlLicense.Cursor := crHandPoint;
    pnlLicense.OnClick := @F.LicenseBtnClick;
    pnlLicense.Tag := 1;

    lblLicense := TLabel.Create(pnlLicense);
    lblLicense.Parent := pnlLicense;
    lblLicense.Align := alClient;
    lblLicense.Alignment := taCenter;
    lblLicense.Layout := tlCenter;
    lblLicense.Font.Height := -13;
    lblLicense.Font.Style := [fsBold];
    lblLicense.Font.Color := Pal.TextInverse;
    lblLicense.Caption := rsLicenseBtn;
    lblLicense.Cursor := crHandPoint;
    lblLicense.OnClick := @F.LicenseBtnClick;

    Inc(YPos, 64);

    { Guidelines }
    pnlGuidelines := TPanel.Create(F);
    pnlGuidelines.Parent := F;
    pnlGuidelines.SetBounds(24, YPos, 452, 48);
    pnlGuidelines.BevelOuter := bvNone;
    pnlGuidelines.Color := Pal.Accent;
    pnlGuidelines.Cursor := crHandPoint;
    pnlGuidelines.OnClick := @F.GuidelinesBtnClick;
    pnlGuidelines.Tag := 2;

    lblGuidelines := TLabel.Create(pnlGuidelines);
    lblGuidelines.Parent := pnlGuidelines;
    lblGuidelines.Align := alClient;
    lblGuidelines.Alignment := taCenter;
    lblGuidelines.Layout := tlCenter;
    lblGuidelines.Font.Height := -13;
    lblGuidelines.Font.Style := [fsBold];
    lblGuidelines.Font.Color := Pal.TextInverse;
    lblGuidelines.Caption := rsGuidelinesBtn;
    lblGuidelines.Cursor := crHandPoint;
    lblGuidelines.OnClick := @F.GuidelinesBtnClick;

    Inc(YPos, 64);

    { Faith }
    pnlFaith := TPanel.Create(F);
    pnlFaith.Parent := F;
    pnlFaith.SetBounds(24, YPos, 452, 48);
    pnlFaith.BevelOuter := bvNone;
    pnlFaith.Color := Pal.Accent;
    pnlFaith.Cursor := crHandPoint;
    pnlFaith.OnClick := @F.FaithBtnClick;
    pnlFaith.Tag := 3;

    lblFaith := TLabel.Create(pnlFaith);
    lblFaith.Parent := pnlFaith;
    lblFaith.Align := alClient;
    lblFaith.Alignment := taCenter;
    lblFaith.Layout := tlCenter;
    lblFaith.Font.Height := -13;
    lblFaith.Font.Style := [fsBold];
    lblFaith.Font.Color := Pal.TextInverse;
    lblFaith.Caption := rsFaithBtn;
    lblFaith.Cursor := crHandPoint;
    lblFaith.OnClick := @F.FaithBtnClick;

    Inc(YPos, 32);

    btnDecline := TButton.Create(F);
    btnDecline.Parent := F;
    btnDecline.SetBounds(300, YPos, 80, 32);
    btnDecline.Caption := rsDeclineBtn;
    btnDecline.ModalResult := mrCancel;
    btnDecline.Kind := bkCancel;

    btnAgree := TButton.Create(F);
    btnAgree.Parent := F;
    btnAgree.SetBounds(392, YPos, 84, 32);
    btnAgree.Caption := rsAgreeBtn;
    btnAgree.ModalResult := mrNone;
    btnAgree.OnClick := @F.AgreeBtnClick;
    btnAgree.Default := True;

    Result := (F.ShowModal = mrOK);
    if Result then
    begin
      SetHasAcceptedTerms(True);  { Add this func to AppSettings }
      LogInfo('Terms accepted');
    end;
  finally
    F.Free;
  end;
end;

end.
