{$mode objfpc}{$H+}
unit GameViewLogin;

{ Login / profile selection screen.

  Shown at startup when no user profile exists (HasUserProfile = False).
  Two paths:
    Local profile  — enter a display name, save to user.json, go to Home.
    Server account — stub; shows "not yet implemented" text.

  Layout: centred card on window background.
  After successful login: Container.View := ViewHome.
}

interface

uses
  Classes,
  CastleUIControls, CastleControls, CastleColors,
  CGEViewBase;

type
  TViewLogin = class(TCGEViewBase)
  private
    FCard         : TCastleRectangleControl;

    { ── main step ── }
    FTitleLbl     : TCastleLabel;
    FSubtitleLbl  : TCastleLabel;
    FLocalBtn     : TCastleButton;
    FServerBtn    : TCastleButton;

    { ── local-profile step ── }
    FLocalPanel   : TCastleRectangleControl;
    FPromptLbl    : TCastleLabel;
    FNameEdit     : TCastleEdit;
    FSubmitBtn    : TCastleButton;
    FBackBtn      : TCastleButton;
    FErrorLbl     : TCastleLabel;

    { ── server-login step ── }
    FServerPanel    : TCastleRectangleControl;
    FSrvURLEdit     : TCastleEdit;
    FSrvUserEdit    : TCastleEdit;
    FSrvPassEdit    : TCastleEdit;
    FSrvLoginBtn    : TCastleButton;
    FSrvBackBtn     : TCastleButton;
    FSrvStatusLbl   : TCastleLabel;

    FShowingLocal  : Boolean;
    FNeedsLogin    : Boolean;   { deferred server login flag }

    procedure BuildChrome;
    procedure ShowMain;
    procedure ShowLocal;
    procedure ShowServer;

    procedure ClickLocal(Sender: TObject);
    procedure ClickServer(Sender: TObject);
    procedure ClickSubmit(Sender: TObject);
    procedure ClickBack(Sender: TObject);
    procedure ClickServerLogin(Sender: TObject);
    procedure ClickServerBack(Sender: TObject);
    procedure DoServerLogin;
  public
    procedure Start;  override;
    procedure Update(const SecondsPassed: Single; var HandleInput: Boolean); override;
    procedure Resize; override;
    procedure OnThemeChange; override;
  end;

var
  ViewLogin: TViewLogin;

implementation

uses
  SysUtils, CastleVectors,
  AppState, BTTTheme, AppLog,
  UserProfile,
  AppSettings,
  GiteaClient,
  GameViewHome, GameViewTerms;

const
  CardW   = 440;
  CardH   = 320;
  Pad     = 28;
  EditW   = 280;
  EditH   = 36;

procedure TViewLogin.Start;
begin
  inherited;
  ApplyBackground;
  FShowingLocal := False;
  FNeedsLogin   := False;
  BuildChrome;
  ShowMain;
end;

procedure TViewLogin.BuildChrome;
var
  Pal : TBTTPalette;
begin
  Pal := P;

  { Centred card }
  FCard       := TCastleRectangleControl.Create(FreeAtStop);
  FCard.Color := Pal.PanelBg;
  FCard.Width  := CardW;
  FCard.Height := CardH;
  FCard.Anchor(hpMiddle, hpMiddle);
  FCard.Anchor(vpMiddle, vpMiddle);
  InsertFront(FCard);

  { ── Main step ── }
  FTitleLbl          := TCastleLabel.Create(FreeAtStop);
  FTitleLbl.Caption  := 'BTT-Writer';
  FTitleLbl.Color    := Pal.TextPrimary;
  FTitleLbl.FontSize := 26;
  FTitleLbl.Anchor(hpMiddle, hpMiddle);
  FTitleLbl.Anchor(vpTop,    vpTop,    -Pad);
  FCard.InsertFront(FTitleLbl);

  FSubtitleLbl          := TCastleLabel.Create(FreeAtStop);
  FSubtitleLbl.Caption  := 'Bible Translation Tool';
  FSubtitleLbl.Color    := Pal.TextSecondary;
  FSubtitleLbl.FontSize := 14;
  FSubtitleLbl.Anchor(hpMiddle, hpMiddle);
  FSubtitleLbl.Anchor(vpTop,    vpTop,    -(Pad + 38));
  FCard.InsertFront(FSubtitleLbl);

  FLocalBtn          := TCastleButton.Create(FreeAtStop);
  FLocalBtn.Caption  := 'Create Local Profile';
  FLocalBtn.FontSize := 15;
  FLocalBtn.Width    := EditW;
  FLocalBtn.OnClick  := @ClickLocal;
  FLocalBtn.Anchor(hpMiddle, hpMiddle);
  FLocalBtn.Anchor(vpMiddle, vpMiddle, 30);
  FCard.InsertFront(FLocalBtn);

  FServerBtn          := TCastleButton.Create(FreeAtStop);
  FServerBtn.Caption  := 'Login with Server Account';
  FServerBtn.FontSize := 14;
  FServerBtn.Width    := EditW;
  FServerBtn.OnClick  := @ClickServer;
  FServerBtn.Anchor(hpMiddle, hpMiddle);
  FServerBtn.Anchor(vpMiddle, vpMiddle, -20);
  FCard.InsertFront(FServerBtn);

  { ── Local-profile step (hidden initially) ── }
  FLocalPanel       := TCastleRectangleControl.Create(FreeAtStop);
  FLocalPanel.Color := Pal.PanelBg;
  FLocalPanel.FullSize := True;
  FLocalPanel.Exists   := False;
  FCard.InsertFront(FLocalPanel);

  FPromptLbl          := TCastleLabel.Create(FreeAtStop);
  FPromptLbl.Caption  := 'Your display name:';
  FPromptLbl.Color    := Pal.TextPrimary;
  FPromptLbl.FontSize := 15;
  FPromptLbl.Anchor(hpMiddle, hpMiddle);
  FPromptLbl.Anchor(vpMiddle, vpMiddle, 60);
  FLocalPanel.InsertFront(FPromptLbl);

  FNameEdit             := TCastleEdit.Create(FreeAtStop);
  FNameEdit.Placeholder := 'Full name or pseudonym';
  FNameEdit.Width       := EditW;
  FNameEdit.FontSize    := 15;
  FNameEdit.Anchor(hpMiddle, hpMiddle);
  FNameEdit.Anchor(vpMiddle, vpMiddle, 20);
  FLocalPanel.InsertFront(FNameEdit);

  FErrorLbl          := TCastleLabel.Create(FreeAtStop);
  FErrorLbl.Caption  := 'Please enter a name.';
  FErrorLbl.Color    := Vector4(0.85, 0.2, 0.2, 1);
  FErrorLbl.FontSize := 13;
  FErrorLbl.Anchor(hpMiddle, hpMiddle);
  FErrorLbl.Anchor(vpMiddle, vpMiddle, 0);
  FErrorLbl.Exists   := False;
  FLocalPanel.InsertFront(FErrorLbl);

  FSubmitBtn          := TCastleButton.Create(FreeAtStop);
  FSubmitBtn.Caption  := 'Continue';
  FSubmitBtn.FontSize := 14;
  FSubmitBtn.Width    := 120;
  FSubmitBtn.OnClick  := @ClickSubmit;
  FSubmitBtn.Anchor(hpMiddle, hpMiddle, 70);
  FSubmitBtn.Anchor(vpMiddle, vpMiddle, -30);
  FLocalPanel.InsertFront(FSubmitBtn);

  FBackBtn          := TCastleButton.Create(FreeAtStop);
  FBackBtn.Caption  := 'Back';
  FBackBtn.FontSize := 14;
  FBackBtn.Width    := 100;
  FBackBtn.OnClick  := @ClickBack;
  FBackBtn.Anchor(hpMiddle, hpMiddle, -70);
  FBackBtn.Anchor(vpMiddle, vpMiddle, -30);
  FLocalPanel.InsertFront(FBackBtn);

  { ── Server-login step (hidden initially) ── }
  FServerPanel       := TCastleRectangleControl.Create(FreeAtStop);
  FServerPanel.Color := Pal.PanelBg;
  FServerPanel.FullSize := True;
  FServerPanel.Exists   := False;
  FCard.InsertFront(FServerPanel);

  FSrvURLEdit             := TCastleEdit.Create(FreeAtStop);
  FSrvURLEdit.Placeholder := 'Server URL';
  FSrvURLEdit.Width       := EditW;
  FSrvURLEdit.FontSize    := 14;
  FSrvURLEdit.Anchor(hpMiddle, hpMiddle);
  FSrvURLEdit.Anchor(vpMiddle, vpMiddle, 75);
  FServerPanel.InsertFront(FSrvURLEdit);

  FSrvUserEdit             := TCastleEdit.Create(FreeAtStop);
  FSrvUserEdit.Placeholder := 'Username';
  FSrvUserEdit.Width       := EditW;
  FSrvUserEdit.FontSize    := 14;
  FSrvUserEdit.Anchor(hpMiddle, hpMiddle);
  FSrvUserEdit.Anchor(vpMiddle, vpMiddle, 30);
  FServerPanel.InsertFront(FSrvUserEdit);

  FSrvPassEdit             := TCastleEdit.Create(FreeAtStop);
  FSrvPassEdit.Placeholder := 'Password';
  FSrvPassEdit.Width       := EditW;
  FSrvPassEdit.FontSize    := 14;
  FSrvPassEdit.PasswordChar := '*';
  FSrvPassEdit.Anchor(hpMiddle, hpMiddle);
  FSrvPassEdit.Anchor(vpMiddle, vpMiddle, -15);
  FServerPanel.InsertFront(FSrvPassEdit);

  FSrvStatusLbl          := TCastleLabel.Create(FreeAtStop);
  FSrvStatusLbl.Caption  := '';
  FSrvStatusLbl.Color    := Vector4(0.85, 0.2, 0.2, 1);
  FSrvStatusLbl.FontSize := 12;
  FSrvStatusLbl.Anchor(hpMiddle, hpMiddle);
  FSrvStatusLbl.Anchor(vpMiddle, vpMiddle, -48);
  FSrvStatusLbl.Exists   := False;
  FServerPanel.InsertFront(FSrvStatusLbl);

  FSrvLoginBtn          := TCastleButton.Create(FreeAtStop);
  FSrvLoginBtn.Caption  := 'Login';
  FSrvLoginBtn.FontSize := 14;
  FSrvLoginBtn.Width    := 120;
  FSrvLoginBtn.OnClick  := @ClickServerLogin;
  FSrvLoginBtn.Anchor(hpMiddle, hpMiddle, 70);
  FSrvLoginBtn.Anchor(vpMiddle, vpMiddle, -70);
  FServerPanel.InsertFront(FSrvLoginBtn);

  FSrvBackBtn          := TCastleButton.Create(FreeAtStop);
  FSrvBackBtn.Caption  := 'Back';
  FSrvBackBtn.FontSize := 14;
  FSrvBackBtn.Width    := 100;
  FSrvBackBtn.OnClick  := @ClickServerBack;
  FSrvBackBtn.Anchor(hpMiddle, hpMiddle, -70);
  FSrvBackBtn.Anchor(vpMiddle, vpMiddle, -70);
  FServerPanel.InsertFront(FSrvBackBtn);
end;

procedure TViewLogin.ShowMain;
begin
  FLocalPanel.Exists  := False;
  FServerPanel.Exists := False;
  FTitleLbl.Exists    := True;
  FSubtitleLbl.Exists := True;
  FLocalBtn.Exists    := True;
  FServerBtn.Exists   := True;
  FShowingLocal       := False;
end;

procedure TViewLogin.ShowLocal;
begin
  FTitleLbl.Exists    := False;
  FSubtitleLbl.Exists := False;
  FLocalBtn.Exists    := False;
  FServerBtn.Exists   := False;
  FLocalPanel.Exists  := True;
  FNameEdit.Text      := '';
  FErrorLbl.Exists    := False;
  FShowingLocal       := True;
end;

procedure TViewLogin.ShowServer;
begin
  FTitleLbl.Exists    := False;
  FSubtitleLbl.Exists := False;
  FLocalBtn.Exists    := False;
  FServerBtn.Exists   := False;
  FLocalPanel.Exists  := False;
  FServerPanel.Exists := True;
  FSrvURLEdit.Text    := GetDataServer;
  FSrvUserEdit.Text   := '';
  FSrvPassEdit.Text   := '';
  FSrvStatusLbl.Exists := False;
  FShowingLocal        := False;
end;

procedure TViewLogin.ClickLocal(Sender: TObject);
begin
  ShowLocal;
end;

procedure TViewLogin.ClickServer(Sender: TObject);
begin
  ShowServer;
end;

procedure TViewLogin.ClickServerLogin(Sender: TObject);
begin
  FSrvLoginBtn.Enabled := False;
  FSrvBackBtn.Enabled  := False;
  FSrvStatusLbl.Caption := 'Logging in…';
  FSrvStatusLbl.Color  := Vector4(0.3, 0.6, 0.3, 1);
  FSrvStatusLbl.Exists := True;
  FNeedsLogin := True;
end;

procedure TViewLogin.ClickServerBack(Sender: TObject);
begin
  ShowMain;
end;

procedure TViewLogin.DoServerLogin;
var
  SrvURL    : string;
  Username  : string;
  Password  : string;
  UserInfo  : TGiteaUserInfo;
  Token     : TGiteaTokenInfo;
  Profile   : TUserProfile;
begin
  FNeedsLogin := False;
  SrvURL   := Trim(FSrvURLEdit.Text);
  Username := Trim(FSrvUserEdit.Text);
  Password := FSrvPassEdit.Text;

  if SrvURL = '' then
  begin
    FSrvStatusLbl.Caption := 'Please enter a server URL.';
    FSrvStatusLbl.Color   := Vector4(0.85, 0.2, 0.2, 1);
    FSrvStatusLbl.Exists  := True;
    FSrvLoginBtn.Enabled  := True;
    FSrvBackBtn.Enabled   := True;
    Exit;
  end;
  if Username = '' then
  begin
    FSrvStatusLbl.Caption := 'Please enter a username.';
    FSrvStatusLbl.Color   := Vector4(0.85, 0.2, 0.2, 1);
    FSrvStatusLbl.Exists  := True;
    FSrvLoginBtn.Enabled  := True;
    FSrvBackBtn.Enabled   := True;
    Exit;
  end;

  try
    GiteaLogin(SrvURL, Username, Password, UserInfo, Token);
  except
    on E: Exception do
    begin
      LogFmt(llWarn, 'Server login failed: %s', [E.Message]);
      FSrvStatusLbl.Caption := 'Login failed: ' + E.Message;
      FSrvStatusLbl.Color   := Vector4(0.85, 0.2, 0.2, 1);
      FSrvStatusLbl.Exists  := True;
      FSrvLoginBtn.Enabled  := True;
      FSrvBackBtn.Enabled   := True;
      Exit;
    end;
  end;

  Profile          := Default(TUserProfile);
  Profile.Username := UserInfo.Username;
  Profile.FullName := UserInfo.FullName;
  Profile.Email    := UserInfo.Email;
  Profile.Token    := Token.SHA1;
  Profile.TokenID  := Token.ID;
  Profile.IsLocal  := False;
  Profile.ServerURL := SrvURL;
  SaveUserProfile(Profile);

  GAppState.UserName := UserInfo.FullName;
  if GAppState.UserName = '' then
    GAppState.UserName := UserInfo.Username;
  GAppState.IsLocal := False;
  LogInfo('Login: server login successful for ' + Profile.Username);

  SetTermsAccepted(False);
  Container.View := ViewTerms;
end;

procedure TViewLogin.ClickSubmit(Sender: TObject);
var
  DisplayName : string;
  Profile     : TUserProfile;
begin
  DisplayName := Trim(FNameEdit.Text);
  if DisplayName = '' then
  begin
    FErrorLbl.Exists := True;
    Exit;
  end;
  FErrorLbl.Exists := False;

  Profile          := Default(TUserProfile);
  Profile.FullName := DisplayName;
  Profile.IsLocal  := True;
  SaveUserProfile(Profile);

  GAppState.UserName := DisplayName;
  GAppState.IsLocal  := True;
  LogInfo('Login: local profile created for ' + DisplayName);

  { New profiles always need to accept Terms, regardless of any saved state. }
  SetTermsAccepted(False);
  Container.View := ViewTerms;
end;

procedure TViewLogin.ClickBack(Sender: TObject);
begin
  ShowMain;
end;

procedure TViewLogin.Update(const SecondsPassed: Single; var HandleInput: Boolean);
begin
  inherited;
  if FNeedsLogin then
    DoServerLogin;
end;

procedure TViewLogin.Resize;
begin
  inherited;
  { Card is centred by anchors; nothing extra needed. }
end;

procedure TViewLogin.OnThemeChange;
begin
  if Container <> nil then
    Container.View := Self;
end;

end.
