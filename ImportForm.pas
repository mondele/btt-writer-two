unit ImportForm;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes;

type
  TImportChoice = (icNone, icServer, icProject, icUSFM, icSourceText);
  TExportChoice = (ecNone, ecServer, ecTStudio, ecUSFM);

function ShowImportDialog(AIsServerUser: Boolean): TImportChoice;
function ShowExportDialog(AIsServerUser: Boolean): TExportChoice;

implementation

uses
  Forms, Controls, StdCtrls, ExtCtrls, Graphics,
  ThemePalette, AppSettings;

resourcestring
  rsImportTitle = 'Import';
  rsImportFromServer = 'Import from Server';
  rsImportProjectFile = 'Import Project File (.tstudio)';
  rsImportUSFMFile = 'Import USFM File';
  rsImportSourceText = 'Import Source Text';
  rsExportTitle = 'Export';
  rsUploadToServer = 'Upload to Server';
  rsExportTStudio = 'Export to Project File (.tstudio)';
  rsExportUSFM = 'Export to USFM File (.usfm)';
  rsCancelBtn = 'Cancel';

type
  TChoiceForm = class(TForm)
  private
    procedure OptionBtnClick(Sender: TObject);
  end;

procedure TChoiceForm.OptionBtnClick(Sender: TObject);
begin
  if Sender is TControl then
  begin
    Tag := TControl(Sender).Tag;
    ModalResult := mrOK;
  end;
end;

function CreateOptionPanel(AOwner: TChoiceForm; AParent: TWinControl;
  const ACaption: string; ATop, ATag: Integer; AEnabled: Boolean;
  const APalette: TThemePalette): TPanel;
var
  Lbl: TLabel;
begin
  Result := TPanel.Create(AOwner);
  Result.Parent := AParent;
  Result.SetBounds(24, ATop, 340, 44);
  Result.BevelOuter := bvNone;
  Result.ParentBackground := False;
  Result.ParentColor := False;
  Result.Tag := ATag;
  if AEnabled then
  begin
    Result.Color := APalette.Accent;
    Result.Cursor := crHandPoint;
    Result.OnClick := @AOwner.OptionBtnClick;
  end
  else
    Result.Color := APalette.Border;
  Result.Enabled := AEnabled;

  Lbl := TLabel.Create(Result);
  Lbl.Parent := Result;
  Lbl.Left := 16;
  Lbl.Top := 12;
  Lbl.Font.Height := -16;
  Lbl.Caption := ACaption;
  Lbl.Tag := ATag;
  if AEnabled then
  begin
    Lbl.Font.Color := APalette.TextInverse;
    Lbl.Cursor := crHandPoint;
    Lbl.OnClick := @AOwner.OptionBtnClick;
  end
  else
    Lbl.Font.Color := APalette.TextMuted;
  Lbl.Enabled := AEnabled;
end;

function ShowImportDialog(AIsServerUser: Boolean): TImportChoice;
var
  F: TChoiceForm;
  Pal: TThemePalette;
  btnCancel: TButton;
begin
  Result := icNone;
  Pal := GetThemePalette(GetEffectiveTheme);

  F := TChoiceForm.CreateNew(nil);
  try
    F.Position := poScreenCenter;
    F.BorderStyle := bsSingle;
    F.Caption := rsImportTitle;
    F.Width := 400;
    F.Height := 340;
    F.Color := Pal.PanelBg;
    F.Tag := 0;

    CreateOptionPanel(F, F, rsImportFromServer, 20, Ord(icServer), AIsServerUser, Pal);
    CreateOptionPanel(F, F, rsImportProjectFile, 74, Ord(icProject), True, Pal);
    CreateOptionPanel(F, F, rsImportUSFMFile, 128, Ord(icUSFM), True, Pal);
    CreateOptionPanel(F, F, rsImportSourceText, 182, Ord(icSourceText), True, Pal);

    btnCancel := TButton.Create(F);
    btnCancel.Parent := F;
    btnCancel.SetBounds(290, 260, 80, 32);
    btnCancel.Caption := rsCancelBtn;
    btnCancel.ModalResult := mrCancel;

    if F.ShowModal = mrOK then
      Result := TImportChoice(F.Tag);
  finally
    F.Free;
  end;
end;

function ShowExportDialog(AIsServerUser: Boolean): TExportChoice;
var
  F: TChoiceForm;
  Pal: TThemePalette;
  btnCancel: TButton;
begin
  Result := ecNone;
  Pal := GetThemePalette(GetEffectiveTheme);

  F := TChoiceForm.CreateNew(nil);
  try
    F.Position := poScreenCenter;
    F.BorderStyle := bsSingle;
    F.Caption := rsExportTitle;
    F.Width := 400;
    F.Height := 280;
    F.Color := Pal.PanelBg;
    F.Tag := 0;

    CreateOptionPanel(F, F, rsUploadToServer, 20, Ord(ecServer), AIsServerUser, Pal);
    CreateOptionPanel(F, F, rsExportTStudio, 74, Ord(ecTStudio), True, Pal);
    CreateOptionPanel(F, F, rsExportUSFM, 128, Ord(ecUSFM), True, Pal);

    btnCancel := TButton.Create(F);
    btnCancel.Parent := F;
    btnCancel.SetBounds(290, 200, 80, 32);
    btnCancel.Caption := rsCancelBtn;
    btnCancel.ModalResult := mrCancel;

    if F.ShowModal = mrOK then
      Result := TExportChoice(F.Tag);
  finally
    F.Free;
  end;
end;

end.
