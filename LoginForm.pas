unit LoginForm;

{$mode objfpc}{$H+}

interface

uses
  UserProfile;

{ Show the profile chooser. Returns True if user completed login/profile setup. }
function ShowLoginDialog(out Profile: TUserProfile): Boolean;

implementation

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, Graphics, Dialogs,
  LCLIntf,
  GiteaClient, AppLog, AppSettings, ThemePalette;

resourcestring
  rsProfileTitle = 'User Profile';
  rsProfilePrompt = 'Setup your User Profile with one of the options below.';
  rsLoginToServer = 'Login to your Server Account';
  rsLoginToServerDesc = 'Use this option to be able to upload projects to your existing account.';
  rsCreateAccount = 'Create a Server Account';
  rsCreateAccountDesc = 'Use this option if you do not have an account but want to upload.';
  rsLocalProfile = 'Create Local User Profile';
  rsLocalProfileDesc = 'Use this option if you do not have an account and do not want to upload.';

  rsServerLoginTitle = 'Server Login';
  rsServerLoginWarning = 'This will use your internet connection.';
  rsUsername = 'Username';
  rsPassword = 'Password';
  rsLogin = 'Login';
  rsCancel = 'Cancel';
  rsCreateNewAccount = 'CREATE A NEW ACCOUNT';
  rsLoginWithServer = 'LOGIN WITH SERVER ACCOUNT';

  rsLocalTitle = 'Local User Profile';
  rsLocalExplanation = 'Enter your full name or pseudonym. This name will be added to ' +
    'the contributor list of all projects you work on. This name will be visible to others.';
  rsFullNameHint = 'Full Name or Pseudonym';
  rsOK = 'OK';

  rsQuit = 'Quit';
  rsLoggingIn = 'Logging in...';
  rsLoginFailed = 'Login failed: ';
  rsNameRequired = 'Please enter a name.';

{ Forward declarations }
function ShowServerLoginDialog(out Profile: TUserProfile): Boolean; forward;
function ShowLocalProfileDialog(out Profile: TUserProfile): Boolean; forward;

{ ---- Profile Chooser ---- }

function ShowLoginDialog(out Profile: TUserProfile): Boolean;
var
  F: TForm;
  lblPrompt: TLabel;
  btnServer, btnCreate, btnLocal: TButton;
  lblServerDesc, lblCreateDesc, lblLocalDesc: TLabel;
  btnQuit: TButton;
  Pal: TThemePalette;
  ModalRes: Integer;
begin
  Result := False;
  Profile := Default(TUserProfile);
  Pal := GetThemePalette(GetEffectiveTheme);

  F := TForm.Create(nil);
  try
    F.Position := poScreenCenter;
    F.BorderStyle := bsSingle;
    F.BorderIcons := [];
    F.Caption := rsProfileTitle;
    F.Font.Name := 'Noto Sans';
    F.Width := 520;
    F.Height := 400;
    F.Color := Pal.PanelBG;

    lblPrompt := TLabel.Create(F);
    lblPrompt.Parent := F;
    lblPrompt.AutoSize := True;
    lblPrompt.Left := 40;
    lblPrompt.Top := 24;
    lblPrompt.Font.Height := -14;
    lblPrompt.Font.Style := [fsBold];
    lblPrompt.Font.Color := Pal.TextPrimary;
    lblPrompt.Caption := rsProfilePrompt;

    { Option 1: Server Login }
    btnServer := TButton.Create(F);
    btnServer.Parent := F;
    btnServer.SetBounds(40, 70, 440, 36);
    btnServer.Caption := rsLoginToServer;
    btnServer.Font.Height := -13;
    btnServer.Font.Style := [fsBold];
    btnServer.ModalResult := mrYes;

    lblServerDesc := TLabel.Create(F);
    lblServerDesc.Parent := F;
    lblServerDesc.Left := 60;
    lblServerDesc.Top := 110;
    lblServerDesc.Font.Height := -11;
    lblServerDesc.Font.Color := Pal.TextSecondary;
    lblServerDesc.Caption := rsLoginToServerDesc;

    { Option 2: Create Account }
    btnCreate := TButton.Create(F);
    btnCreate.Parent := F;
    btnCreate.SetBounds(40, 150, 440, 36);
    btnCreate.Caption := rsCreateAccount;
    btnCreate.Font.Height := -13;
    btnCreate.Font.Style := [fsBold];
    btnCreate.ModalResult := mrNo;

    lblCreateDesc := TLabel.Create(F);
    lblCreateDesc.Parent := F;
    lblCreateDesc.Left := 60;
    lblCreateDesc.Top := 190;
    lblCreateDesc.Font.Height := -11;
    lblCreateDesc.Font.Color := Pal.TextSecondary;
    lblCreateDesc.Caption := rsCreateAccountDesc;

    { Option 3: Local Profile }
    btnLocal := TButton.Create(F);
    btnLocal.Parent := F;
    btnLocal.SetBounds(40, 230, 440, 36);
    btnLocal.Caption := rsLocalProfile;
    btnLocal.Font.Height := -13;
    btnLocal.Font.Style := [fsBold];
    btnLocal.ModalResult := mrAll;

    lblLocalDesc := TLabel.Create(F);
    lblLocalDesc.Parent := F;
    lblLocalDesc.Left := 60;
    lblLocalDesc.Top := 270;
    lblLocalDesc.Font.Height := -11;
    lblLocalDesc.Font.Color := Pal.TextSecondary;
    lblLocalDesc.Caption := rsLocalProfileDesc;

    btnQuit := TButton.Create(F);
    btnQuit.Parent := F;
    btnQuit.SetBounds(40, 320, 440, 30);
    btnQuit.Caption := rsQuit;
    btnQuit.ModalResult := mrClose;

    repeat
      ModalRes := F.ShowModal;
      if ModalRes = mrClose then
      begin
        Result := False;
        Break;
      end;
      case ModalRes of
        mrYes:
          Result := ShowServerLoginDialog(Profile);
        mrNo:
        begin
          { Open account creation page in browser }
          OpenURL(AccountCreationURL(DefaultDataServerURL));
          { Then show the server login dialog so they can log in after creating }
          Result := ShowServerLoginDialog(Profile);
        end;
        mrAll:
          Result := ShowLocalProfileDialog(Profile);
      end;
    until Result;  { Keep showing chooser until user completes a login/profile }
  finally
    F.Free;
  end;
end;

{ ---- Server Login Dialog ---- }

function ShowServerLoginDialog(out Profile: TUserProfile): Boolean;
var
  F: TForm;
  lblTitle, lblWarning: TLabel;
  edUser, edPass: TEdit;
  lblUser, lblPass: TLabel;
  btnLogin, btnCancel: TButton;
  btnCreateLink: TLabel;
  Pal: TThemePalette;
  UserInfo: TGiteaUserInfo;
  Token: TGiteaTokenInfo;
  ServerURL: string;
begin
  Result := False;
  Profile := Default(TUserProfile);
  Pal := GetThemePalette(GetEffectiveTheme);
  ServerURL := DefaultDataServerURL;

  F := TForm.Create(nil);
  try
    F.Position := poScreenCenter;
    F.BorderStyle := bsSingle;
    F.BorderIcons := [];
    F.Caption := rsProfileTitle;
    F.Font.Name := 'Noto Sans';
    F.Width := 460;
    F.Height := 320;
    F.Color := Pal.PanelBG;

    lblTitle := TLabel.Create(F);
    lblTitle.Parent := F;
    lblTitle.Left := 40;
    lblTitle.Top := 24;
    lblTitle.Font.Height := -18;
    lblTitle.Font.Style := [fsBold];
    lblTitle.Font.Color := Pal.TextPrimary;
    lblTitle.Caption := rsServerLoginTitle;

    lblWarning := TLabel.Create(F);
    lblWarning.Parent := F;
    lblWarning.Left := 40;
    lblWarning.Top := 56;
    lblWarning.Font.Height := -11;
    lblWarning.Font.Color := Pal.TextSecondary;
    lblWarning.Caption := rsServerLoginWarning;

    lblUser := TLabel.Create(F);
    lblUser.Parent := F;
    lblUser.Left := 40;
    lblUser.Top := 90;
    lblUser.Caption := rsUsername;
    lblUser.Font.Color := Pal.TextSecondary;

    edUser := TEdit.Create(F);
    edUser.Parent := F;
    edUser.SetBounds(40, 110, 380, 28);
    edUser.Font.Height := -13;

    lblPass := TLabel.Create(F);
    lblPass.Parent := F;
    lblPass.Left := 40;
    lblPass.Top := 148;
    lblPass.Caption := rsPassword;
    lblPass.Font.Color := Pal.TextSecondary;

    edPass := TEdit.Create(F);
    edPass.Parent := F;
    edPass.SetBounds(40, 168, 380, 28);
    edPass.Font.Height := -13;
    edPass.EchoMode := emPassword;

    btnCreateLink := TLabel.Create(F);
    btnCreateLink.Parent := F;
    btnCreateLink.Left := 40;
    btnCreateLink.Top := 228;
    btnCreateLink.Caption := rsCreateNewAccount;
    btnCreateLink.Font.Height := -11;
    btnCreateLink.Font.Color := Pal.TextSecondary;
    btnCreateLink.Cursor := crHandPoint;

    btnCancel := TButton.Create(F);
    btnCancel.Parent := F;
    btnCancel.SetBounds(260, 220, 70, 32);
    btnCancel.Caption := rsCancel;
    btnCancel.ModalResult := mrCancel;

    btnLogin := TButton.Create(F);
    btnLogin.Parent := F;
    btnLogin.SetBounds(340, 220, 80, 32);
    btnLogin.Caption := rsLogin;
    btnLogin.Default := True;
    btnLogin.ModalResult := mrOK;

    while True do
    begin
      if F.ShowModal <> mrOK then
        Exit;

      if Trim(edUser.Text) = '' then
      begin
        edUser.SetFocus;
        Continue;
      end;

      { Attempt login }
      F.Caption := rsLoggingIn;
      F.Update;
      try
        GiteaLogin(ServerURL, Trim(edUser.Text), edPass.Text, UserInfo, Token);

        Profile.Username := UserInfo.Username;
        Profile.FullName := UserInfo.FullName;
        Profile.Email := UserInfo.Email;
        Profile.Token := Token.SHA1;
        Profile.TokenID := Token.ID;
        Profile.IsLocal := False;
        Profile.ServerURL := ServerURL;
        Result := True;
        Exit;
      except
        on E: Exception do
        begin
          F.Caption := rsProfileTitle;
          LogFmt(llWarn, 'Server login failed: %s', [E.Message]);
          ShowMessage(rsLoginFailed + E.Message);
        end;
      end;
    end;
  finally
    F.Free;
  end;
end;

{ ---- Local Profile Dialog ---- }

function ShowLocalProfileDialog(out Profile: TUserProfile): Boolean;
var
  F: TForm;
  lblTitle, lblExplain: TLabel;
  edName: TEdit;
  btnOK, btnCancel: TButton;
  btnServerLink: TLabel;
  Pal: TThemePalette;
begin
  Result := False;
  Profile := Default(TUserProfile);
  Pal := GetThemePalette(GetEffectiveTheme);

  F := TForm.Create(nil);
  try
    F.Position := poScreenCenter;
    F.BorderStyle := bsSingle;
    F.BorderIcons := [];
    F.Caption := rsProfileTitle;
    F.Font.Name := 'Noto Sans';
    F.Width := 460;
    F.Height := 300;
    F.Color := Pal.PanelBG;

    lblTitle := TLabel.Create(F);
    lblTitle.Parent := F;
    lblTitle.Left := 40;
    lblTitle.Top := 24;
    lblTitle.Font.Height := -18;
    lblTitle.Font.Style := [fsBold];
    lblTitle.Font.Color := Pal.TextPrimary;
    lblTitle.Caption := rsLocalTitle;

    lblExplain := TLabel.Create(F);
    lblExplain.Parent := F;
    lblExplain.SetBounds(40, 60, 380, 60);
    lblExplain.WordWrap := True;
    lblExplain.Font.Height := -12;
    lblExplain.Font.Color := Pal.TextSecondary;
    lblExplain.Caption := rsLocalExplanation;

    edName := TEdit.Create(F);
    edName.Parent := F;
    edName.SetBounds(40, 140, 380, 28);
    edName.Font.Height := -13;
    edName.TextHint := rsFullNameHint;

    btnServerLink := TLabel.Create(F);
    btnServerLink.Parent := F;
    btnServerLink.Left := 40;
    btnServerLink.Top := 208;
    btnServerLink.Caption := rsLoginWithServer;
    btnServerLink.Font.Height := -11;
    btnServerLink.Font.Color := Pal.TextSecondary;
    btnServerLink.Cursor := crHandPoint;

    btnCancel := TButton.Create(F);
    btnCancel.Parent := F;
    btnCancel.SetBounds(260, 200, 70, 32);
    btnCancel.Caption := rsCancel;
    btnCancel.ModalResult := mrCancel;

    btnOK := TButton.Create(F);
    btnOK.Parent := F;
    btnOK.SetBounds(340, 200, 80, 32);
    btnOK.Caption := rsOK;
    btnOK.Default := True;
    btnOK.ModalResult := mrOK;

    while True do
    begin
      if F.ShowModal <> mrOK then
        Exit;

      if Trim(edName.Text) = '' then
      begin
        ShowMessage(rsNameRequired);
        edName.SetFocus;
        Continue;
      end;

      Profile.FullName := Trim(edName.Text);
      Profile.IsLocal := True;
      Result := True;
      Exit;
    end;
  finally
    F.Free;
  end;
end;

end.
