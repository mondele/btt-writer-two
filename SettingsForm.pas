unit SettingsForm;

{$mode objfpc}{$H+}

interface

uses
  AppSettings;

{ Shows the full settings dialog. Returns True if user clicked OK. }
function ShowSettingsDialog(out OldTheme, NewTheme: TAppTheme;
  out OldSuite, NewSuite: string): Boolean;

implementation

uses
  Forms, Controls, StdCtrls, ComCtrls, ExtCtrls, Dialogs, Graphics,
  Classes, SysUtils, Process, Globals, DataPaths, LegalTexts, ThemePalette;

resourcestring
  rsSettingsCaption = 'Settings';
  rsOK = 'OK';
  rsCancel = 'Cancel';

  { General tab }
  rsTabGeneral = 'General';
  rsInterfaceLangLabel = 'Interface Language';
  rsGatewayLangMode = 'Gateway Language Mode';
  rsGatewayLangDesc = 'When enabled, adds resource translation options (Notes, Questions) alongside text translation.';
  rsBlindEditMode = 'Blind Edit Mode';
  rsBlindEditDesc = 'Source and translation are never visible simultaneously during drafting.';
  rsColorThemeLabel = 'Color Theme';
  rsThemeSystem = 'System';
  rsThemeLight = 'Light';
  rsThemeDark = 'Dark';
  rsBackupLocationLabel = 'Backup Location';
  rsBackupBrowse = 'Browse...';
  rsBackupNotSet = '(not set)';

  { About tab }
  rsTabAbout = 'About';
  rsAppVersionLabel = 'App Version:';
  rsGitVersionLabel = 'Git Version:';
  rsDataPathLabel = 'Data Path:';

  { Legal tab }
  rsTabLegal = 'Legal';
  rsBtnLicenseAgreement = 'License Agreement';
  rsBtnTranslationGuidelines = 'Translation Guidelines';
  rsBtnStatementOfFaith = 'Statement of Faith';
  rsBtnSoftwareLicenses = 'Software Licenses';

  { Advanced tab }
  rsTabAdvanced = 'Advanced';
  rsServerSuiteLabel = 'Server Suite';
  rsSuiteWACS = 'WACS';
  rsSuiteDCS = 'DCS';
  rsDataServerLabel = 'Data Server';
  rsMediaServerLabel = 'Media Server';
  rsReaderServerLabel = 'Reader Server';
  rsCreateAccountURLLabel = 'Create Account URL';
  rsLanguagesURLLabel = 'Languages URL';
  rsIndexSQLiteURLLabel = 'Index.sqlite URL';
  rsTransManualURLLabel = 'Translation Manual URL';
  rsDeveloperToolsLabel = 'Developer Tools';
  rsSuiteChangeWarn = 'Changing server suite will update all server URLs. Continue?';

  rsClose = 'Close';

type
  { Helper class to hold event handlers for the settings dialog }
  TSettingsHelper = class
    FForm: TForm;
    lblBackupValue: TLabel;
    cmbSuite: TComboBox;
    edDS, edMS, edRS, edCA, edLU, edIU, edTU: TEdit;
    CurrentSuiteIdx: Integer;
    procedure BackupBrowseClick(Sender: TObject);
    procedure SuiteComboChange(Sender: TObject);
    procedure LicenseClick(Sender: TObject);
    procedure GuidelinesClick(Sender: TObject);
    procedure StatementClick(Sender: TObject);
    procedure SoftwareClick(Sender: TObject);
    procedure PopulateURLEdits;
  end;

procedure ShowLegalTextDialog(AOwner: TComponent; const ATitle, AText: string);
var
  F: TForm;
  Memo: TMemo;
  Btn: TButton;
  Pal: TThemePalette;
begin
  Pal := GetThemePalette(GetEffectiveTheme);
  F := TForm.Create(AOwner);
  try
    F.Position := poScreenCenter;
    F.Caption := ATitle;
    F.Font.Name := 'Noto Sans';
    F.Width := 600;
    F.Height := 500;
    F.Color := Pal.PanelBg;
    F.BorderIcons := [biSystemMenu];

    Memo := TMemo.Create(F);
    Memo.Parent := F;
    Memo.Align := alClient;
    Memo.BorderSpacing.Around := 12;
    Memo.ReadOnly := True;
    Memo.ScrollBars := ssVertical;
    Memo.WordWrap := True;
    Memo.Font.Name := 'Noto Sans';
    Memo.Font.Height := -13;
    Memo.Font.Color := Pal.TextPrimary;
    Memo.Color := Pal.MemoBg;
    Memo.Lines.Text := AText;

    Btn := TButton.Create(F);
    Btn.Parent := F;
    Btn.Caption := rsClose;
    Btn.Align := alBottom;
    Btn.Height := 36;
    Btn.ModalResult := mrOK;

    F.ShowModal;
  finally
    F.Free;
  end;
end;

function GetGitVersionString: string;
var
  P: TProcess;
  OutS: TStringStream;
begin
  Result := '(unknown)';
  P := TProcess.Create(nil);
  OutS := TStringStream.Create('');
  try
    P.Executable := 'git';
    P.Parameters.Add('--version');
    P.Options := [poUsePipes, poWaitOnExit, poStderrToOutPut];
    try
      P.Execute;
      OutS.CopyFrom(P.Output, 0);
      Result := Trim(OutS.DataString);
    except
    end;
  finally
    OutS.Free;
    P.Free;
  end;
end;

{ TSettingsHelper }

procedure TSettingsHelper.PopulateURLEdits;
var
  DS, MS, RS, CA, LU, IU, TU: string;
  SuiteName: string;
begin
  if cmbSuite.ItemIndex = 1 then
    SuiteName := 'dcs'
  else
    SuiteName := 'wacs';
  GetSuiteDefaults(SuiteName, DS, MS, RS, CA, LU, IU, TU);
  edDS.Text := DS;
  edMS.Text := MS;
  edRS.Text := RS;
  edCA.Text := CA;
  edLU.Text := LU;
  edIU.Text := IU;
  edTU.Text := TU;
end;

procedure TSettingsHelper.SuiteComboChange(Sender: TObject);
begin
  if cmbSuite.ItemIndex = CurrentSuiteIdx then
    Exit;
  if MessageDlg(rsSuiteChangeWarn, mtConfirmation, [mbYes, mbNo], 0) = mrYes then
  begin
    CurrentSuiteIdx := cmbSuite.ItemIndex;
    PopulateURLEdits;
  end
  else
    cmbSuite.ItemIndex := CurrentSuiteIdx;
end;

procedure TSettingsHelper.BackupBrowseClick(Sender: TObject);
var
  Dlg: TSelectDirectoryDialog;
begin
  Dlg := TSelectDirectoryDialog.Create(FForm);
  try
    if lblBackupValue.Caption <> rsBackupNotSet then
      Dlg.InitialDir := lblBackupValue.Caption;
    if Dlg.Execute then
      lblBackupValue.Caption := Dlg.FileName;
  finally
    Dlg.Free;
  end;
end;

procedure TSettingsHelper.LicenseClick(Sender: TObject);
begin
  ShowLegalTextDialog(FForm, rsLicenseTitle, rsLicenseAgreement);
end;

procedure TSettingsHelper.GuidelinesClick(Sender: TObject);
begin
  ShowLegalTextDialog(FForm, rsGuidelinesTitle, rsTranslationGuidelines);
end;

procedure TSettingsHelper.StatementClick(Sender: TObject);
begin
  ShowLegalTextDialog(FForm, rsStatementTitle, rsStatementOfFaith);
end;

procedure TSettingsHelper.SoftwareClick(Sender: TObject);
begin
  ShowLegalTextDialog(FForm, rsSoftwareTitle, rsSoftwareLicenses);
end;

{ Main dialog function }

function MakeLabelEdit(AOwner: TComponent; AParent: TWinControl;
  const ACaption: string; ATop: Integer; APal: TThemePalette;
  out AEdit: TEdit): TLabel;
begin
  Result := TLabel.Create(AOwner);
  Result.Parent := AParent;
  Result.Left := 20;
  Result.Top := ATop;
  Result.Caption := ACaption;
  Result.Font.Color := APal.TextSecondary;

  AEdit := TEdit.Create(AOwner);
  AEdit.Parent := AParent;
  AEdit.Left := 20;
  AEdit.Top := ATop + 18;
  AEdit.Width := 610;
  AEdit.Font.Name := 'Noto Sans';
end;

function ShowSettingsDialog(out OldTheme, NewTheme: TAppTheme;
  out OldSuite, NewSuite: string): Boolean;
var
  F: TForm;
  Pages: TPageControl;
  TabGeneral, TabAbout, TabLegal, TabAdvanced: TTabSheet;
  BtnOK, BtnCancel: TButton;
  BtnPanel: TPanel;
  Pal: TThemePalette;
  Y: Integer;
  Helper: TSettingsHelper;

  { General tab controls }
  lblLang: TLabel;
  cmbLang: TComboBox;
  chkGateway: TCheckBox;
  lblGatewayDesc: TLabel;
  chkBlindEdit: TCheckBox;
  lblBlindEditDesc: TLabel;
  lblTheme: TLabel;
  cmbTheme: TComboBox;
  lblBackupPath: TLabel;
  btnBackupBrowse: TButton;

  { About tab controls }
  lblAppVerTitle, lblAppVerValue: TLabel;
  lblGitVerTitle, lblGitVerValue: TLabel;
  lblDataPathTitle, lblDataPathValue: TLabel;

  { Legal tab controls }
  btnLicense, btnGuidelines, btnStatement, btnSoftware: TButton;

  { Advanced tab controls }
  lblSuite: TLabel;
  chkDevTools: TCheckBox;
  DummyLabel: TLabel;
begin
  Result := False;
  Pal := GetThemePalette(GetEffectiveTheme);
  OldTheme := GetAppTheme;
  OldSuite := GetServerSuite;

  Helper := TSettingsHelper.Create;
  try
    F := TForm.Create(nil);
    try
      Helper.FForm := F;
      F.Position := poScreenCenter;
      F.BorderIcons := [biSystemMenu];
      F.Caption := rsSettingsCaption;
      F.Font.Name := 'Noto Sans';
      F.Width := 700;
      F.Height := 550;
      F.Color := Pal.PanelBg;

      { Button panel at bottom }
      BtnPanel := TPanel.Create(F);
      BtnPanel.Parent := F;
      BtnPanel.Align := alBottom;
      BtnPanel.Height := 48;
      BtnPanel.BevelOuter := bvNone;
      BtnPanel.Color := Pal.PanelBg;

      BtnOK := TButton.Create(F);
      BtnOK.Parent := BtnPanel;
      BtnOK.Caption := rsOK;
      BtnOK.Width := 80;
      BtnOK.Left := F.Width - 200;
      BtnOK.Top := 8;
      BtnOK.Anchors := [akTop, akRight];
      BtnOK.ModalResult := mrOK;
      BtnOK.Default := True;

      BtnCancel := TButton.Create(F);
      BtnCancel.Parent := BtnPanel;
      BtnCancel.Caption := rsCancel;
      BtnCancel.Width := 80;
      BtnCancel.Left := F.Width - 110;
      BtnCancel.Top := 8;
      BtnCancel.Anchors := [akTop, akRight];
      BtnCancel.ModalResult := mrCancel;

      { Page control }
      Pages := TPageControl.Create(F);
      Pages.Parent := F;
      Pages.Align := alClient;
      Pages.Font.Name := 'Noto Sans';

      { ===== General Tab ===== }
      TabGeneral := TTabSheet.Create(Pages);
      TabGeneral.PageControl := Pages;
      TabGeneral.Caption := rsTabGeneral;

      Y := 20;

      lblLang := TLabel.Create(F);
      lblLang.Parent := TabGeneral;
      lblLang.Left := 20;
      lblLang.Top := Y;
      lblLang.Caption := rsInterfaceLangLabel;
      lblLang.Font.Color := Pal.TextSecondary;

      cmbLang := TComboBox.Create(F);
      cmbLang.Parent := TabGeneral;
      cmbLang.Left := 20;
      cmbLang.Top := Y + 20;
      cmbLang.Width := 300;
      cmbLang.Style := csDropDownList;
      cmbLang.Items.Add('English');
      cmbLang.ItemIndex := 0;

      Y := Y + 60;

      chkGateway := TCheckBox.Create(F);
      chkGateway.Parent := TabGeneral;
      chkGateway.Left := 20;
      chkGateway.Top := Y;
      chkGateway.Width := 600;
      chkGateway.Caption := rsGatewayLangMode;
      chkGateway.Checked := GetGatewayLanguageMode;

      lblGatewayDesc := TLabel.Create(F);
      lblGatewayDesc.Parent := TabGeneral;
      lblGatewayDesc.Left := 40;
      lblGatewayDesc.Top := Y + 24;
      lblGatewayDesc.Width := 580;
      lblGatewayDesc.WordWrap := True;
      lblGatewayDesc.Caption := rsGatewayLangDesc;
      lblGatewayDesc.Font.Color := Pal.TextMuted;
      lblGatewayDesc.Font.Height := -11;

      Y := Y + 64;

      chkBlindEdit := TCheckBox.Create(F);
      chkBlindEdit.Parent := TabGeneral;
      chkBlindEdit.Left := 20;
      chkBlindEdit.Top := Y;
      chkBlindEdit.Width := 600;
      chkBlindEdit.Caption := rsBlindEditMode;
      chkBlindEdit.Checked := GetBlindEditMode;

      lblBlindEditDesc := TLabel.Create(F);
      lblBlindEditDesc.Parent := TabGeneral;
      lblBlindEditDesc.Left := 40;
      lblBlindEditDesc.Top := Y + 24;
      lblBlindEditDesc.Width := 580;
      lblBlindEditDesc.WordWrap := True;
      lblBlindEditDesc.Caption := rsBlindEditDesc;
      lblBlindEditDesc.Font.Color := Pal.TextMuted;
      lblBlindEditDesc.Font.Height := -11;

      Y := Y + 64;

      lblTheme := TLabel.Create(F);
      lblTheme.Parent := TabGeneral;
      lblTheme.Left := 20;
      lblTheme.Top := Y;
      lblTheme.Caption := rsColorThemeLabel;
      lblTheme.Font.Color := Pal.TextSecondary;

      cmbTheme := TComboBox.Create(F);
      cmbTheme.Parent := TabGeneral;
      cmbTheme.Left := 20;
      cmbTheme.Top := Y + 20;
      cmbTheme.Width := 300;
      cmbTheme.Style := csDropDownList;
      cmbTheme.Items.Add(rsThemeSystem);  { 0 }
      cmbTheme.Items.Add(rsThemeLight);   { 1 }
      cmbTheme.Items.Add(rsThemeDark);    { 2 }
      case OldTheme of
        atLight:  cmbTheme.ItemIndex := 1;
        atDark:   cmbTheme.ItemIndex := 2;
      else
        cmbTheme.ItemIndex := 0;
      end;

      Y := Y + 60;

      lblBackupPath := TLabel.Create(F);
      lblBackupPath.Parent := TabGeneral;
      lblBackupPath.Left := 20;
      lblBackupPath.Top := Y;
      lblBackupPath.Caption := rsBackupLocationLabel;
      lblBackupPath.Font.Color := Pal.TextSecondary;

      Helper.lblBackupValue := TLabel.Create(F);
      Helper.lblBackupValue.Parent := TabGeneral;
      Helper.lblBackupValue.Left := 20;
      Helper.lblBackupValue.Top := Y + 20;
      Helper.lblBackupValue.Width := 500;
      Helper.lblBackupValue.Font.Color := Pal.TextPrimary;
      Helper.lblBackupValue.Caption := GetEffectiveBackupLocation;

      btnBackupBrowse := TButton.Create(F);
      btnBackupBrowse.Parent := TabGeneral;
      btnBackupBrowse.Left := 540;
      btnBackupBrowse.Top := Y + 16;
      btnBackupBrowse.Width := 90;
      btnBackupBrowse.Caption := rsBackupBrowse;
      btnBackupBrowse.OnClick := @Helper.BackupBrowseClick;

      { ===== About Tab ===== }
      TabAbout := TTabSheet.Create(Pages);
      TabAbout.PageControl := Pages;
      TabAbout.Caption := rsTabAbout;

      Y := 30;

      lblAppVerTitle := TLabel.Create(F);
      lblAppVerTitle.Parent := TabAbout;
      lblAppVerTitle.Left := 30;
      lblAppVerTitle.Top := Y;
      lblAppVerTitle.Caption := rsAppVersionLabel;
      lblAppVerTitle.Font.Style := [fsBold];
      lblAppVerTitle.Font.Color := Pal.TextPrimary;

      lblAppVerValue := TLabel.Create(F);
      lblAppVerValue.Parent := TabAbout;
      lblAppVerValue.Left := 200;
      lblAppVerValue.Top := Y;
      lblAppVerValue.Caption := APP_VERSION;
      lblAppVerValue.Font.Color := Pal.TextSecondary;

      Y := Y + 36;

      lblGitVerTitle := TLabel.Create(F);
      lblGitVerTitle.Parent := TabAbout;
      lblGitVerTitle.Left := 30;
      lblGitVerTitle.Top := Y;
      lblGitVerTitle.Caption := rsGitVersionLabel;
      lblGitVerTitle.Font.Style := [fsBold];
      lblGitVerTitle.Font.Color := Pal.TextPrimary;

      lblGitVerValue := TLabel.Create(F);
      lblGitVerValue.Parent := TabAbout;
      lblGitVerValue.Left := 200;
      lblGitVerValue.Top := Y;
      lblGitVerValue.Caption := GetGitVersionString;
      lblGitVerValue.Font.Color := Pal.TextSecondary;

      Y := Y + 36;

      lblDataPathTitle := TLabel.Create(F);
      lblDataPathTitle.Parent := TabAbout;
      lblDataPathTitle.Left := 30;
      lblDataPathTitle.Top := Y;
      lblDataPathTitle.Caption := rsDataPathLabel;
      lblDataPathTitle.Font.Style := [fsBold];
      lblDataPathTitle.Font.Color := Pal.TextPrimary;

      lblDataPathValue := TLabel.Create(F);
      lblDataPathValue.Parent := TabAbout;
      lblDataPathValue.Left := 200;
      lblDataPathValue.Top := Y;
      lblDataPathValue.Caption := GetDataPath;
      lblDataPathValue.Font.Color := Pal.TextSecondary;

      { ===== Legal Tab ===== }
      TabLegal := TTabSheet.Create(Pages);
      TabLegal.PageControl := Pages;
      TabLegal.Caption := rsTabLegal;

      Y := 30;

      btnLicense := TButton.Create(F);
      btnLicense.Parent := TabLegal;
      btnLicense.Left := 30;
      btnLicense.Top := Y;
      btnLicense.Width := 280;
      btnLicense.Height := 36;
      btnLicense.Caption := rsBtnLicenseAgreement;
      btnLicense.OnClick := @Helper.LicenseClick;

      Y := Y + 50;

      btnGuidelines := TButton.Create(F);
      btnGuidelines.Parent := TabLegal;
      btnGuidelines.Left := 30;
      btnGuidelines.Top := Y;
      btnGuidelines.Width := 280;
      btnGuidelines.Height := 36;
      btnGuidelines.Caption := rsBtnTranslationGuidelines;
      btnGuidelines.OnClick := @Helper.GuidelinesClick;

      Y := Y + 50;

      btnStatement := TButton.Create(F);
      btnStatement.Parent := TabLegal;
      btnStatement.Left := 30;
      btnStatement.Top := Y;
      btnStatement.Width := 280;
      btnStatement.Height := 36;
      btnStatement.Caption := rsBtnStatementOfFaith;
      btnStatement.OnClick := @Helper.StatementClick;

      Y := Y + 50;

      btnSoftware := TButton.Create(F);
      btnSoftware.Parent := TabLegal;
      btnSoftware.Left := 30;
      btnSoftware.Top := Y;
      btnSoftware.Width := 280;
      btnSoftware.Height := 36;
      btnSoftware.Caption := rsBtnSoftwareLicenses;
      btnSoftware.OnClick := @Helper.SoftwareClick;

      { ===== Advanced Tab ===== }
      TabAdvanced := TTabSheet.Create(Pages);
      TabAdvanced.PageControl := Pages;
      TabAdvanced.Caption := rsTabAdvanced;

      Y := 16;

      lblSuite := TLabel.Create(F);
      lblSuite.Parent := TabAdvanced;
      lblSuite.Left := 20;
      lblSuite.Top := Y;
      lblSuite.Caption := rsServerSuiteLabel;
      lblSuite.Font.Color := Pal.TextSecondary;

      Helper.cmbSuite := TComboBox.Create(F);
      Helper.cmbSuite.Parent := TabAdvanced;
      Helper.cmbSuite.Left := 20;
      Helper.cmbSuite.Top := Y + 18;
      Helper.cmbSuite.Width := 200;
      Helper.cmbSuite.Style := csDropDownList;
      Helper.cmbSuite.Items.Add(rsSuiteWACS);  { 0 }
      Helper.cmbSuite.Items.Add(rsSuiteDCS);   { 1 }
      if LowerCase(Trim(GetServerSuite)) = 'dcs' then
        Helper.cmbSuite.ItemIndex := 1
      else
        Helper.cmbSuite.ItemIndex := 0;
      Helper.CurrentSuiteIdx := Helper.cmbSuite.ItemIndex;
      Helper.cmbSuite.OnChange := @Helper.SuiteComboChange;

      Y := Y + 52;

      { URL fields }
      DummyLabel := MakeLabelEdit(F, TabAdvanced, rsDataServerLabel, Y, Pal, Helper.edDS);
      Y := Y + 46;
      DummyLabel := MakeLabelEdit(F, TabAdvanced, rsMediaServerLabel, Y, Pal, Helper.edMS);
      Y := Y + 46;
      DummyLabel := MakeLabelEdit(F, TabAdvanced, rsReaderServerLabel, Y, Pal, Helper.edRS);
      Y := Y + 46;
      DummyLabel := MakeLabelEdit(F, TabAdvanced, rsCreateAccountURLLabel, Y, Pal, Helper.edCA);
      Y := Y + 46;
      DummyLabel := MakeLabelEdit(F, TabAdvanced, rsLanguagesURLLabel, Y, Pal, Helper.edLU);
      Y := Y + 46;
      DummyLabel := MakeLabelEdit(F, TabAdvanced, rsIndexSQLiteURLLabel, Y, Pal, Helper.edIU);
      Y := Y + 46;
      DummyLabel := MakeLabelEdit(F, TabAdvanced, rsTransManualURLLabel, Y, Pal, Helper.edTU);
      Y := Y + 52;

      { Populate URL edits from current settings, or suite defaults if all empty }
      Helper.edDS.Text := GetDataServer;
      Helper.edMS.Text := GetMediaServer;
      Helper.edRS.Text := GetReaderServer;
      Helper.edCA.Text := GetCreateAccountURL;
      Helper.edLU.Text := GetLanguagesURL;
      Helper.edIU.Text := GetIndexSQLiteURL;
      Helper.edTU.Text := GetTranslationManualURL;
      if (Helper.edDS.Text = '') and (Helper.edMS.Text = '') then
        Helper.PopulateURLEdits;

      chkDevTools := TCheckBox.Create(F);
      chkDevTools.Parent := TabAdvanced;
      chkDevTools.Left := 20;
      chkDevTools.Top := Y;
      chkDevTools.Width := 300;
      chkDevTools.Caption := rsDeveloperToolsLabel;
      chkDevTools.Checked := GetDeveloperTools;

      { ===== Show Dialog ===== }
      if F.ShowModal = mrOK then
      begin
        { Read theme }
        case cmbTheme.ItemIndex of
          1: NewTheme := atLight;
          2: NewTheme := atDark;
        else
          NewTheme := atSystem;
        end;

        { Read suite }
        if Helper.cmbSuite.ItemIndex = 1 then
          NewSuite := 'dcs'
        else
          NewSuite := 'wacs';

        { Persist everything }
        SetAppTheme(NewTheme, True);
        SetGatewayLanguageMode(chkGateway.Checked);
        SetBlindEditMode(chkBlindEdit.Checked);
        SetDeveloperTools(chkDevTools.Checked);

        SetBackupLocation(Helper.lblBackupValue.Caption);

        { Server URLs }
        SetServerSuite(NewSuite);
        SetDataServer(Helper.edDS.Text);
        SetMediaServer(Helper.edMS.Text);
        SetReaderServer(Helper.edRS.Text);
        SetCreateAccountURL(Helper.edCA.Text);
        SetLanguagesURL(Helper.edLU.Text);
        SetIndexSQLiteURL(Helper.edIU.Text);
        SetTranslationManualURL(Helper.edTU.Text);

        Result := True;
      end
      else
      begin
        NewTheme := OldTheme;
        NewSuite := OldSuite;
      end;
    finally
      F.Free;
    end;
  finally
    Helper.Free;
  end;
end;

end.
