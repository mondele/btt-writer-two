unit SettingsForm;

{$mode objfpc}{$H+}

interface

uses
  AppSettings;

function ShowThemeSettingsDialog(var Theme: TAppTheme): Boolean;

implementation

uses
  Forms, Controls, StdCtrls, Classes, SysUtils;

resourcestring
  rsSettingsCaption = 'Settings';
  rsThemeLabel = 'Theme';
  rsThemeLight = 'Light';
  rsThemeDark = 'Dark';
  rsOK = 'OK';
  rsCancel = 'Cancel';

function ShowThemeSettingsDialog(var Theme: TAppTheme): Boolean;
var
  F: TForm;
  Lbl: TLabel;
  Cmb: TComboBox;
  BtnOK, BtnCancel: TButton;
begin
  Result := False;
  F := TForm.Create(nil);
  try
    F.Position := poScreenCenter;
    F.BorderIcons := [biSystemMenu];
    F.Caption := rsSettingsCaption;
    F.Font.Name := 'Noto Sans';
    F.Width := 320;
    F.Height := 150;

    Lbl := TLabel.Create(F);
    Lbl.Parent := F;
    Lbl.Left := 16;
    Lbl.Top := 16;
    Lbl.Caption := rsThemeLabel;

    Cmb := TComboBox.Create(F);
    Cmb.Parent := F;
    Cmb.Left := 16;
    Cmb.Top := 36;
    Cmb.Width := 280;
    Cmb.Style := csDropDownList;
    Cmb.Items.Add(rsThemeLight);
    Cmb.Items.Add(rsThemeDark);
    case Theme of
      atDark: Cmb.ItemIndex := 1;
    else
      Cmb.ItemIndex := 0;
    end;

    BtnOK := TButton.Create(F);
    BtnOK.Parent := F;
    BtnOK.Caption := rsOK;
    BtnOK.Left := 130;
    BtnOK.Top := 82;
    BtnOK.Width := 80;
    BtnOK.ModalResult := mrOK;
    BtnOK.Default := True;

    BtnCancel := TButton.Create(F);
    BtnCancel.Parent := F;
    BtnCancel.Caption := rsCancel;
    BtnCancel.Left := 216;
    BtnCancel.Top := 82;
    BtnCancel.Width := 80;
    BtnCancel.ModalResult := mrCancel;

    if F.ShowModal = mrOK then
    begin
      if Cmb.ItemIndex = 1 then
        Theme := atDark
      else
        Theme := atLight;
      Result := True;
    end;
  finally
    F.Free;
  end;
end;

end.
