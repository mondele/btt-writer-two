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
  CastleUIControls, CastleControls, CastleColors, CastleKeysMouse,
  CGEViewBase, BTTHeader, BTTBreadcrumb, BTTStatusBar, BTTTheme;

type
  { Clickable row used in the chooser card.
    Wraps a title + description and fires OnOptionClick on left-press. }
  TLoginOptionRow = class(TCastleRectangleControl)
  private
    FOnOptionClick: TNotifyEvent;
  public
    function Press(const Event: TInputPressRelease): Boolean; override;
    property OnOptionClick: TNotifyEvent read FOnOptionClick write FOnOptionClick;
  end;

  TViewLogin = class(TCGEViewBase)
  private
    FHeader       : TBTTHeader;
    FCrumb        : TBTTBreadcrumb;
    FStatusBar    : TBTTStatusBar;
    FCard         : TCastleRectangleControl;

    { ── chooser step ── }
    FChooserPanel : TCastleRectangleControl;
    FChooserIntro : TCastleLabel;
    FRowServer    : TLoginOptionRow;
    FRowCreateSrv : TLoginOptionRow;
    FRowLocal     : TLoginOptionRow;

    { ── local-profile step ── }
    FLocalPanel   : TCastleRectangleControl;
    FLocalTitle   : TCastleLabel;
    FLocalDesc    : TCastleLabel;
    FLocalSep     : TCastleRectangleControl;
    FNameEdit     : TCastleEdit;
    FErrorLbl     : TCastleLabel;
    FSubmitBtn    : TCastleButton;          { green OK, outside card }
    FLocalToSrvBtn: TCastleButton;          { text link, outside card }

    { ── server-login step ── }
    FServerPanel   : TCastleRectangleControl;
    FServerTitle   : TCastleLabel;
    FServerNetLbl  : TCastleLabel;
    FServerSep     : TCastleRectangleControl;
    FSrvUserEdit   : TCastleEdit;
    FSrvPassEdit   : TCastleEdit;
    FSrvStatusLbl  : TCastleLabel;
    FSrvLoginBtn   : TCastleButton;         { green LOGIN, outside card }
    FSrvCreateBtn  : TCastleButton;         { text link, outside card }

    FShowingLocal  : Boolean;
    FNeedsLogin    : Boolean;   { deferred server login flag }

    procedure BuildChrome;
    procedure BuildChooser(const Pal: TBTTPalette);
    procedure BuildLocalPanel(const Pal: TBTTPalette);
    procedure BuildServerPanel(const Pal: TBTTPalette);
    procedure ShowMain;
    procedure ShowLocal;
    procedure ShowServer;

    procedure StyleLinkButton(Btn: TCastleButton; const Pal: TBTTPalette);
    procedure StylePrimaryButton(Btn: TCastleButton; const Pal: TBTTPalette);

    procedure ClickLocal(Sender: TObject);
    procedure ClickServer(Sender: TObject);
    procedure ClickCreateServer(Sender: TObject);
    procedure ClickSubmit(Sender: TObject);
    procedure ClickBack(Sender: TObject);
    procedure ClickServerLogin(Sender: TObject);
    procedure ClickServerBack(Sender: TObject);
    procedure ClickCreateServerAcct(Sender: TObject);
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
  AppState, AppLog,
  UserProfile,
  AppSettings,
  GiteaClient, CGEStrings,
  GameViewHome, GameViewTerms;

const
  CardW      = 560;
  CardH      = 360;
  Pad        = 24;
  OptionH    = 96;    { height of each chooser option row }
  SepH       = 1;
  EditH      = 38;

{ ── TLoginOptionRow ───────────────────────────────────────────────────────── }

function TLoginOptionRow.Press(const Event: TInputPressRelease): Boolean;
begin
  Result := inherited Press(Event);
  if (Event.EventType = itMouseButton) and (Event.MouseButton = buttonLeft) then
  begin
    if Assigned(FOnOptionClick) then
      FOnOptionClick(Self);
    Result := True;
  end;
end;

procedure TViewLogin.Start;
begin
  inherited;
  ApplyBackground;
  FShowingLocal := False;
  FNeedsLogin   := False;
  BuildChrome;
  ShowMain;
end;

procedure TViewLogin.StyleLinkButton(Btn: TCastleButton; const Pal: TBTTPalette);
begin
  Btn.CustomBackground    := True;
  Btn.CustomColorNormal   := Vector4(0, 0, 0, 0);
  Btn.CustomColorFocused  := Vector4(0, 0, 0, 0.05);
  Btn.CustomColorPressed  := Vector4(0, 0, 0, 0.10);
  Btn.CustomColorDisabled := Vector4(0, 0, 0, 0);
  Btn.CustomTextColorUse  := True;
  Btn.CustomTextColor     := Pal.TextSecondary;
end;

procedure TViewLogin.StylePrimaryButton(Btn: TCastleButton; const Pal: TBTTPalette);
begin
  Btn.CustomBackground    := True;
  Btn.CustomColorNormal   := Pal.Accent;
  Btn.CustomColorFocused  := Pal.Accent;
  Btn.CustomColorPressed  := Pal.Accent;
  Btn.CustomTextColorUse  := True;
  Btn.CustomTextColor     := Pal.TextInverse;
  Btn.AutoSize := False;
  Btn.Height   := 44;
end;

procedure TViewLogin.BuildChrome;
var
  Pal : TBTTPalette;
begin
  Pal := P;

  { Header / breadcrumb / status bar chrome }
  FHeader := TBTTHeader.Create(FreeAtStop, Pal);
  FHeader.SetTitle(rsAppName);
  InsertFront(FHeader);

  FCrumb := TBTTBreadcrumb.Create(FreeAtStop, Pal);
  FCrumb.SetCrumbs([rsLoginCrumb]);
  InsertFront(FCrumb);

  FStatusBar := TBTTStatusBar.Create(FreeAtStop, Pal);
  InsertFront(FStatusBar);

  { Centred card — holds whichever step is active. Size set in Resize. }
  FCard       := TCastleRectangleControl.Create(FreeAtStop);
  FCard.Color := Pal.PanelBg;
  FCard.Width  := CardW;
  FCard.Height := CardH;
  FCard.Anchor(hpMiddle, hpMiddle);
  FCard.Anchor(vpMiddle, vpMiddle);
  InsertFront(FCard);

  BuildChooser(Pal);
  BuildLocalPanel(Pal);
  BuildServerPanel(Pal);
end;

procedure TViewLogin.BuildChooser(const Pal: TBTTPalette);

  function MakeOptionRow(const ATitle, ADesc: string;
    OnClickHandler: TNotifyEvent; RowIdx: Integer): TLoginOptionRow;
  var
    TitleLbl, DescLbl : TCastleLabel;
    Sep               : TCastleRectangleControl;
    YBase             : Single;
  begin
    Result := TLoginOptionRow.Create(FreeAtStop);
    Result.Color := Pal.PanelBg;
    Result.OnOptionClick := OnClickHandler;
    FChooserPanel.InsertFront(Result);

    TitleLbl          := TCastleLabel.Create(FreeAtStop);
    TitleLbl.Caption  := ATitle;
    TitleLbl.Color    := Pal.TextPrimary;
    TitleLbl.FontSize := 17;
    TitleLbl.Alignment := hpMiddle;
    TitleLbl.Anchor(hpMiddle, hpMiddle);
    TitleLbl.Anchor(vpTop, vpTop, -18);
    Result.InsertFront(TitleLbl);

    DescLbl          := TCastleLabel.Create(FreeAtStop);
    DescLbl.Caption  := ADesc;
    DescLbl.Color    := Pal.TextSecondary;
    DescLbl.FontSize := 13;
    DescLbl.Alignment := hpMiddle;
    DescLbl.Anchor(hpMiddle, hpMiddle);
    DescLbl.Anchor(vpBottom, vpBottom, 22);
    Result.InsertFront(DescLbl);

    YBase := RowIdx * OptionH;
    Result.Anchor(hpLeft, hpLeft, 0);
    Result.Anchor(vpTop,  vpTop,  -YBase);

    { Hairline separator above the row (except first). }
    if RowIdx > 0 then
    begin
      Sep        := TCastleRectangleControl.Create(FreeAtStop);
      Sep.Color  := Pal.Border;
      Sep.Height := SepH;
      Sep.Anchor(hpLeft,  hpLeft,  24);
      Sep.Anchor(hpRight, hpRight, -24);
      Sep.Anchor(vpTop,   vpTop,   -YBase);
      FChooserPanel.InsertFront(Sep);
    end;
  end;

begin
  FChooserPanel        := TCastleRectangleControl.Create(FreeAtStop);
  FChooserPanel.Color  := Pal.PanelBg;
  FChooserPanel.FullSize := True;
  FCard.InsertFront(FChooserPanel);

  FChooserIntro          := TCastleLabel.Create(FreeAtStop);
  FChooserIntro.Caption  := rsLoginChooserTitle;
  FChooserIntro.Color    := Pal.TextPrimary;
  FChooserIntro.FontSize := 15;
  FChooserIntro.Alignment := hpMiddle;
  FChooserIntro.Anchor(hpMiddle, hpMiddle);
  FChooserIntro.Anchor(vpTop, vpTop, -22);
  FChooserPanel.InsertFront(FChooserIntro);

  { Option rows — stacked, offset below the intro via Resize. }
  FRowServer    := MakeOptionRow(rsLoginOptServerTitle,
                                 rsLoginOptServerDesc,     @ClickServer,       0);
  FRowCreateSrv := MakeOptionRow(rsLoginOptCreateServerTitle,
                                 rsLoginOptCreateServerDesc, @ClickCreateServer, 1);
  FRowLocal     := MakeOptionRow(rsLoginOptLocalTitle,
                                 rsLoginOptLocalDesc,      @ClickLocal,        2);
end;

procedure TViewLogin.BuildLocalPanel(const Pal: TBTTPalette);
begin
  FLocalPanel        := TCastleRectangleControl.Create(FreeAtStop);
  FLocalPanel.Color  := Pal.PanelBg;
  FLocalPanel.FullSize := True;
  FLocalPanel.Exists := False;
  FCard.InsertFront(FLocalPanel);

  FLocalTitle          := TCastleLabel.Create(FreeAtStop);
  FLocalTitle.Caption  := rsLoginLocalHeading;
  FLocalTitle.Color    := Pal.TextPrimary;
  FLocalTitle.FontSize := 20;
  FLocalTitle.Alignment := hpMiddle;
  FLocalTitle.Anchor(hpMiddle, hpMiddle);
  FLocalTitle.Anchor(vpTop, vpTop, -22);
  FLocalPanel.InsertFront(FLocalTitle);

  FLocalDesc          := TCastleLabel.Create(FreeAtStop);
  FLocalDesc.Caption  := rsLoginLocalDesc;
  FLocalDesc.Color    := Pal.TextPrimary;
  FLocalDesc.FontSize := 13;
  FLocalDesc.Alignment := hpMiddle;
  FLocalDesc.Anchor(hpMiddle, hpMiddle);
  FLocalDesc.Anchor(vpTop, vpTop, -56);
  FLocalPanel.InsertFront(FLocalDesc);

  FLocalSep        := TCastleRectangleControl.Create(FreeAtStop);
  FLocalSep.Color  := Pal.Border;
  FLocalSep.Height := SepH;
  FLocalSep.Anchor(hpLeft,  hpLeft,  24);
  FLocalSep.Anchor(hpRight, hpRight, -24);
  FLocalSep.Anchor(vpTop, vpTop, -156);
  FLocalPanel.InsertFront(FLocalSep);

  FNameEdit             := TCastleEdit.Create(FreeAtStop);
  FNameEdit.Placeholder := rsLoginLocalPlaceholder;
  FNameEdit.FontSize    := 16;
  FNameEdit.Anchor(hpLeft,  hpLeft,  Pad);
  FNameEdit.Anchor(vpTop, vpTop, -186);
  FLocalPanel.InsertFront(FNameEdit);

  FErrorLbl          := TCastleLabel.Create(FreeAtStop);
  FErrorLbl.Caption  := rsLoginLocalError;
  FErrorLbl.Color    := Vector4(0.85, 0.2, 0.2, 1);
  FErrorLbl.FontSize := 13;
  FErrorLbl.Anchor(hpMiddle, hpMiddle);
  FErrorLbl.Anchor(vpBottom, vpBottom, 16);
  FErrorLbl.Exists   := False;
  FLocalPanel.InsertFront(FErrorLbl);

  { Outside the card: LOGIN WITH SERVER text-link and green OK button.
    Positioned in Resize so they sit beneath the card's bottom-right. }
  FLocalToSrvBtn          := TCastleButton.Create(FreeAtStop);
  FLocalToSrvBtn.Caption  := rsLoginLocalToServer;
  FLocalToSrvBtn.FontSize := 13;
  FLocalToSrvBtn.OnClick  := @ClickServer;
  StyleLinkButton(FLocalToSrvBtn, Pal);
  FLocalToSrvBtn.Exists   := False;
  InsertFront(FLocalToSrvBtn);

  FSubmitBtn          := TCastleButton.Create(FreeAtStop);
  FSubmitBtn.Caption  := rsLoginLocalSubmit;
  FSubmitBtn.FontSize := 14;
  FSubmitBtn.Width    := 100;
  FSubmitBtn.OnClick  := @ClickSubmit;
  StylePrimaryButton(FSubmitBtn, Pal);
  FSubmitBtn.Exists   := False;
  InsertFront(FSubmitBtn);
end;

procedure TViewLogin.BuildServerPanel(const Pal: TBTTPalette);
begin
  FServerPanel        := TCastleRectangleControl.Create(FreeAtStop);
  FServerPanel.Color  := Pal.PanelBg;
  FServerPanel.FullSize := True;
  FServerPanel.Exists := False;
  FCard.InsertFront(FServerPanel);

  FServerTitle          := TCastleLabel.Create(FreeAtStop);
  FServerTitle.Caption  := rsLoginServerHeading;
  FServerTitle.Color    := Pal.TextPrimary;
  FServerTitle.FontSize := 20;
  FServerTitle.Alignment := hpMiddle;
  FServerTitle.Anchor(hpMiddle, hpMiddle);
  FServerTitle.Anchor(vpTop, vpTop, -22);
  FServerPanel.InsertFront(FServerTitle);

  FServerNetLbl          := TCastleLabel.Create(FreeAtStop);
  FServerNetLbl.Caption  := #$E2#$9F#$B3 + '  ' + rsLoginServerNetWarning;  { ⟳ placeholder for wifi glyph }
  FServerNetLbl.Color    := Pal.TextPrimary;
  FServerNetLbl.FontSize := 13;
  FServerNetLbl.Alignment := hpMiddle;
  FServerNetLbl.Anchor(hpMiddle, hpMiddle);
  FServerNetLbl.Anchor(vpTop, vpTop, -56);
  FServerPanel.InsertFront(FServerNetLbl);

  FServerSep        := TCastleRectangleControl.Create(FreeAtStop);
  FServerSep.Color  := Pal.Border;
  FServerSep.Height := SepH;
  FServerSep.Anchor(hpLeft,  hpLeft,  24);
  FServerSep.Anchor(hpRight, hpRight, -24);
  FServerSep.Anchor(vpTop, vpTop, -90);
  FServerPanel.InsertFront(FServerSep);

  FSrvUserEdit             := TCastleEdit.Create(FreeAtStop);
  FSrvUserEdit.Placeholder := rsLoginServerUser;
  FSrvUserEdit.FontSize    := 16;
  FSrvUserEdit.Anchor(hpLeft, hpLeft, Pad);
  FSrvUserEdit.Anchor(vpTop, vpTop, -120);
  FServerPanel.InsertFront(FSrvUserEdit);

  FSrvPassEdit             := TCastleEdit.Create(FreeAtStop);
  FSrvPassEdit.Placeholder := rsLoginServerPass;
  FSrvPassEdit.FontSize    := 16;
  FSrvPassEdit.PasswordChar := '*';
  FSrvPassEdit.Anchor(hpLeft, hpLeft, Pad);
  FSrvPassEdit.Anchor(vpTop, vpTop, -168);
  FServerPanel.InsertFront(FSrvPassEdit);

  FSrvStatusLbl          := TCastleLabel.Create(FreeAtStop);
  FSrvStatusLbl.Caption  := '';
  FSrvStatusLbl.Color    := Vector4(0.85, 0.2, 0.2, 1);
  FSrvStatusLbl.FontSize := 13;
  FSrvStatusLbl.Anchor(hpMiddle, hpMiddle);
  FSrvStatusLbl.Anchor(vpBottom, vpBottom, 16);
  FSrvStatusLbl.Exists   := False;
  FServerPanel.InsertFront(FSrvStatusLbl);

  { Outside the card: CREATE A NEW ACCOUNT text-link and green LOGIN button. }
  FSrvCreateBtn          := TCastleButton.Create(FreeAtStop);
  FSrvCreateBtn.Caption  := rsLoginServerCreate;
  FSrvCreateBtn.FontSize := 13;
  FSrvCreateBtn.OnClick  := @ClickCreateServerAcct;
  StyleLinkButton(FSrvCreateBtn, Pal);
  FSrvCreateBtn.Exists   := False;
  InsertFront(FSrvCreateBtn);

  FSrvLoginBtn          := TCastleButton.Create(FreeAtStop);
  FSrvLoginBtn.Caption  := rsLoginServerSubmit;
  FSrvLoginBtn.FontSize := 14;
  FSrvLoginBtn.Width    := 110;
  FSrvLoginBtn.OnClick  := @ClickServerLogin;
  StylePrimaryButton(FSrvLoginBtn, Pal);
  FSrvLoginBtn.Exists   := False;
  InsertFront(FSrvLoginBtn);
end;

procedure TViewLogin.ShowMain;
begin
  FChooserPanel.Exists := True;
  FLocalPanel.Exists   := False;
  FServerPanel.Exists  := False;
  FSubmitBtn.Exists     := False;
  FLocalToSrvBtn.Exists := False;
  FSrvLoginBtn.Exists   := False;
  FSrvCreateBtn.Exists  := False;
  FShowingLocal        := False;
  if FCrumb <> nil then
  begin
    FCrumb.OnBack := nil;
    FCrumb.SetCrumbs([rsLoginCrumb]);
  end;
end;

procedure TViewLogin.ShowLocal;
begin
  FChooserPanel.Exists := False;
  FServerPanel.Exists  := False;
  FLocalPanel.Exists   := True;
  FNameEdit.Text       := '';
  FErrorLbl.Exists     := False;
  FSubmitBtn.Exists    := True;
  FLocalToSrvBtn.Exists := True;
  FSrvLoginBtn.Exists  := False;
  FSrvCreateBtn.Exists := False;
  FShowingLocal        := True;
  if FCrumb <> nil then
  begin
    FCrumb.OnBack := @ClickBack;
    FCrumb.SetCrumbs([rsLoginCrumb, rsLoginLocalCrumb]);
  end;
end;

procedure TViewLogin.ShowServer;
begin
  FChooserPanel.Exists := False;
  FLocalPanel.Exists   := False;
  FServerPanel.Exists  := True;
  FSrvUserEdit.Text    := '';
  FSrvPassEdit.Text    := '';
  FSrvStatusLbl.Exists := False;
  FSubmitBtn.Exists     := False;
  FLocalToSrvBtn.Exists := False;
  FSrvLoginBtn.Exists  := True;
  FSrvCreateBtn.Exists := True;
  FShowingLocal        := False;
  if FCrumb <> nil then
  begin
    FCrumb.OnBack := @ClickServerBack;
    FCrumb.SetCrumbs([rsLoginCrumb, rsLoginServerCrumb]);
  end;
end;

procedure TViewLogin.ClickLocal(Sender: TObject);
begin
  ShowLocal;
end;

procedure TViewLogin.ClickServer(Sender: TObject);
begin
  ShowServer;
end;

procedure TViewLogin.ClickCreateServer(Sender: TObject);
begin
  { Create-a-server-account: same flow as login-to-server for now. }
  ShowServer;
end;

procedure TViewLogin.ClickCreateServerAcct(Sender: TObject);
begin
  { Stub: open signup URL in browser. No-op for now. }
  LogInfo('Login: "Create a new account" tapped (browser launch not yet implemented)');
end;

procedure TViewLogin.ClickServerLogin(Sender: TObject);
begin
  FSrvLoginBtn.Enabled  := False;
  FSrvCreateBtn.Enabled := False;
  FSrvStatusLbl.Caption := rsStatusLoggingIn;
  FSrvStatusLbl.Color   := Vector4(0.3, 0.6, 0.3, 1);
  FSrvStatusLbl.Exists  := True;
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
  SrvURL   := GetDataServer;
  if SrvURL = '' then
    SrvURL := DefaultDataServerURL;
  Username := Trim(FSrvUserEdit.Text);
  Password := FSrvPassEdit.Text;

  if Username = '' then
  begin
    FSrvStatusLbl.Caption := rsLoginServerNeedUser;
    FSrvStatusLbl.Color   := Vector4(0.85, 0.2, 0.2, 1);
    FSrvStatusLbl.Exists  := True;
    FSrvLoginBtn.Enabled  := True;
    FSrvCreateBtn.Enabled := True;
    Exit;
  end;

  try
    GiteaLogin(SrvURL, Username, Password, UserInfo, Token);
  except
    on E: Exception do
    begin
      LogFmt(llWarn, 'Server login failed: %s', [E.Message]);
      FSrvStatusLbl.Caption := Format(rsLoginServerFailed, [E.Message]);
      FSrvStatusLbl.Color   := Vector4(0.85, 0.2, 0.2, 1);
      FSrvStatusLbl.Exists  := True;
      FSrvLoginBtn.Enabled  := True;
      FSrvCreateBtn.Enabled := True;
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
var
  W, H, CardX, CardY, EditW: Single;
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

  { Card is centred by its anchors. Compute its screen-space origin so
    we can place the external buttons (OK / LOGIN / text links) just
    beneath its bottom-right edge. }
  CardX := (W - CardW) / 2;
  CardY := (H - CardH) / 2;
  EditW := CardW - Pad * 2;

  { Size chooser option rows (opposite-anchor bug — set width explicitly). }
  if FRowServer <> nil then
  begin
    FRowServer.Width    := CardW;
    FRowServer.Height   := OptionH;
    FRowCreateSrv.Width := CardW;
    FRowCreateSrv.Height := OptionH;
    FRowLocal.Width     := CardW;
    FRowLocal.Height    := OptionH;
  end;

  { Local panel: name field fills card width minus padding. }
  if FNameEdit <> nil then
    FNameEdit.Width := EditW;

  { Server panel: user + pass fields. }
  if FSrvUserEdit <> nil then
    FSrvUserEdit.Width := EditW;
  if FSrvPassEdit <> nil then
    FSrvPassEdit.Width := EditW;

  { External buttons — positioned ~20px below the card's bottom-right. }
  if FSubmitBtn.Exists then
  begin
    FSubmitBtn.Translation   := Vector2(CardX + CardW - FSubmitBtn.Width, CardY - 56);
    FLocalToSrvBtn.Translation :=
      Vector2(CardX + CardW - FSubmitBtn.Width - 220, CardY - 48);
  end;
  if FSrvLoginBtn.Exists then
  begin
    FSrvLoginBtn.Translation := Vector2(CardX + CardW - FSrvLoginBtn.Width, CardY - 56);
    FSrvCreateBtn.Translation :=
      Vector2(CardX + CardW - FSrvLoginBtn.Width - 210, CardY - 48);
  end;
end;

procedure TViewLogin.OnThemeChange;
begin
  if Container <> nil then
    Container.View := Self;
end;

end.
