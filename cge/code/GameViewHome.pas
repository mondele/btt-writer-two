{$mode objfpc}{$H+}
unit GameViewHome;

{ Home screen — Phase 2/3.
  Chrome: BTTHeader (top) | BTTSideRail (left) | content bar + project list.
  Main menu popup slides in from ⋮; a full-screen backdrop dismisses it on
  any outside click.
  Logout uses PushView(TViewConfirm); result is checked in Resume. }

interface

uses
  Classes,
  CastleUIControls, CastleControls, CastleColors, CastleVectors, CastleKeysMouse,
  CGEViewBase, BTTHeader, BTTSideRail, BTTPopupMenu, BTTStatusBar, GameViewConfirm,
  ProjectScanner;

type
  { Full-screen dimmer that dismisses the popup on any outside click. }
  TPopupBackdrop = class(TCastleRectangleControl)
  private
    FMenu: TBTTPopupMenu;
  public
    function Press(const Event: TInputPressRelease): Boolean; override;
    property Menu: TBTTPopupMenu read FMenu write FMenu;
  end;

  TViewHome = class(TCGEViewBase)
  private
    FHeader      : TBTTHeader;
    FUserLbl     : TCastleLabel;
    FRail        : TBTTSideRail;
    FStatusBar   : TBTTStatusBar;
    FContentBar  : TCastleRectangleControl;
    FHeadingLbl  : TCastleLabel;
    FNewProjBtn  : TCastleButton;
    FScrollView  : TCastleScrollView;
    FMenuPopup      : TBTTPopupMenu;
    FBackdrop       : TPopupBackdrop;
    FProjects         : TProjectSummaryList;
    FConfirmLogout    : TViewConfirm;
    FPendingLogout    : Boolean;  { deferred from Resume to avoid lifecycle crash }

    procedure BuildChrome;
    procedure BuildMenuPopup;
    procedure BuildProjectList;
    procedure UpdateScrollArea;

    procedure ClickProject(Sender: TObject);
    procedure ClickNewProject(Sender: TObject);
    procedure ClickMenu(Sender: TObject);

    { Menu item handlers — each closes the popup then acts. }
    procedure MenuDismiss;
    procedure MenuUpdateClick(Sender: TObject);
    procedure MenuImportClick(Sender: TObject);
    procedure MenuAcademyClick(Sender: TObject);
    procedure MenuFeedbackClick(Sender: TObject);
    procedure MenuLogoutClick(Sender: TObject);
    procedure MenuSettingsClick(Sender: TObject);
  public
    procedure Start; override;
    procedure Resume; override;
    procedure Update(const SecondsPassed: Single; var HandleInput: Boolean); override;
    procedure Resize; override;
    procedure OnThemeChange; override;
  end;

var
  ViewHome: TViewHome;

implementation

uses
  SysUtils,
  AppState, BTTTheme, AppLog,
  UserProfile,
  GameViewEditor, GameViewLogin, GameViewSettings, GameViewNewProject,
  GameViewImport, GameViewFeedback;

const
  RowH         = 72;
  RowGap       = 2;
  RowPad       = 16;
  ContentBarH  = 52;

{ TPopupBackdrop }

function TPopupBackdrop.Press(const Event: TInputPressRelease): Boolean;
begin
  Result := inherited Press(Event);
  if (Event.EventType = itMouseButton) and (Event.MouseButton = buttonLeft) then
  begin
    Exists := False;
    if Assigned(FMenu) then
      FMenu.Exists := False;
    Result := True;
  end;
end;

{ TViewHome }

procedure TViewHome.Start;
begin
  inherited;
  ApplyBackground;
  FProjects := ScanProjects;
  BuildChrome;
  BuildMenuPopup;
  BuildProjectList;
end;

procedure TViewHome.BuildChrome;
var
  Pal: TBTTPalette;
begin
  Pal := P;

  { Scroll view first (bottommost) }
  FScrollView := TCastleScrollView.Create(FreeAtStop);
  InsertFront(FScrollView);

  { Content bar — heading strip above the scroll view }
  FContentBar := TCastleRectangleControl.Create(FreeAtStop);
  FContentBar.Color := Pal.ContentBg;
  InsertFront(FContentBar);

  FHeadingLbl := TCastleLabel.Create(FreeAtStop);
  FHeadingLbl.Caption  := 'Your Translation Projects';
  FHeadingLbl.Color    := Pal.TextPrimary;
  FHeadingLbl.FontSize := 18;
  FHeadingLbl.Anchor(hpLeft, hpLeft, RowPad);
  FHeadingLbl.Anchor(vpMiddle, vpMiddle);
  FContentBar.InsertFront(FHeadingLbl);

  { Floating action button — green "+" in the top-right of content area.
    Added to the main view (not content bar) so it z-orders above both
    the content bar and the project list. }
  FNewProjBtn := TCastleButton.Create(FreeAtStop);
  FNewProjBtn.Caption  := '+';
  FNewProjBtn.FontSize := 28;
  FNewProjBtn.OnClick  := @ClickNewProject;
  FNewProjBtn.CustomBackground    := True;
  FNewProjBtn.CustomColorNormal   := Pal.Accent;
  FNewProjBtn.CustomColorFocused  := Pal.Accent;
  FNewProjBtn.CustomColorPressed  := Pal.Accent;
  FNewProjBtn.CustomTextColorUse  := True;
  FNewProjBtn.CustomTextColor     := Pal.TextInverse;
  FNewProjBtn.AutoSize := False;
  FNewProjBtn.Width    := 56;
  FNewProjBtn.Height   := 56;

  { Left rail }
  FRail := TBTTSideRail.Create(FreeAtStop, Pal);
  FRail.OnMenuClick := @ClickMenu;
  InsertFront(FRail);

  { Header on top }
  FHeader := TBTTHeader.Create(FreeAtStop, Pal);
  FHeader.SetTitle('BTT-Writer');
  InsertFront(FHeader);

  FUserLbl := TCastleLabel.Create(FreeAtStop);
  FUserLbl.Caption  := GAppState.UserName;
  FUserLbl.Color    := Pal.TextInverse;
  FUserLbl.FontSize := 13;
  FHeader.AddRight(FUserLbl);

  { Status bar — pinned to the bottom }
  FStatusBar := TBTTStatusBar.Create(FreeAtStop, Pal);
  InsertFront(FStatusBar);

  { FAB on top of content area — positioned in Resize. }
  InsertFront(FNewProjBtn);

  { Backdrop — hidden, in front of content but behind popup }
  FBackdrop := TPopupBackdrop.Create(FreeAtStop);
  FBackdrop.Color  := Vector4(0, 0, 0, 0.18);
  FBackdrop.Menu   := nil; { set after popup is created }
  FBackdrop.FullSize := True;
  FBackdrop.Exists   := False;
  InsertFront(FBackdrop);
end;

procedure TViewHome.BuildMenuPopup;
begin
  FMenuPopup := TBTTPopupMenu.Create(FreeAtStop, P);
  FMenuPopup.AddItem('Update',             #$E2#$9F#$B3, @MenuUpdateClick);            { ⟳ U+27F3 }
  FMenuPopup.AddItem('Import ...',         #$E2#$A4#$93, @MenuImportClick);            { ⤓ U+2913 }
  FMenuPopup.AddItem('translationAcademy', #$E2#$98#$B0, @MenuAcademyClick);           { ☰ placeholder — would be a book }
  FMenuPopup.AddItem('Feedback',           #$E2#$9C#$89, @MenuFeedbackClick);          { ✉ U+2709 }
  FMenuPopup.AddItem('Logout',             #$E2#$86#$AA, @MenuLogoutClick);            { ↪ U+21AA }
  FMenuPopup.AddItem('Settings',           #$E2#$9A#$99, @MenuSettingsClick);          { ⚙ U+2699 }
  FMenuPopup.Build;
  InsertFront(FMenuPopup);    { on top of backdrop }
  FBackdrop.Menu := FMenuPopup;
end;

procedure TViewHome.BuildProjectList;
var
  Pal: TBTTPalette;
  I: Integer;
  Row: TCastleRectangleControl;
  NameLbl, DetailLbl, ProgLbl: TCastleLabel;
  WelcomeCard: TCastleRectangleControl;
  WelcomeTitle, WelcomeBody: TCastleLabel;
  StartBtn: TCastleButton;
  Btn: TCastleButton;
  Pct: Integer;
begin
  Pal := P;

  if Length(FProjects) = 0 then
  begin
    { Welcome card — matches v1 home-en.png empty state. }
    WelcomeCard        := TCastleRectangleControl.Create(FreeAtStop);
    WelcomeCard.Color  := Pal.PanelBg;
    WelcomeCard.Width  := 520;
    WelcomeCard.Height := 210;
    WelcomeCard.Anchor(hpMiddle, hpMiddle);
    WelcomeCard.Anchor(vpMiddle, vpMiddle, 60);
    FScrollView.ScrollArea.InsertFront(WelcomeCard);

    WelcomeTitle          := TCastleLabel.Create(FreeAtStop);
    WelcomeTitle.Caption  := 'Welcome!';
    WelcomeTitle.Color    := Pal.TextPrimary;
    WelcomeTitle.FontSize := 22;
    WelcomeTitle.Anchor(hpLeft, hpLeft, 32);
    WelcomeTitle.Anchor(vpTop,  vpTop,  -28);
    WelcomeCard.InsertFront(WelcomeTitle);

    WelcomeBody          := TCastleLabel.Create(FreeAtStop);
    WelcomeBody.Caption  :=
      'This is your Home Screen. When you have translation' + LineEnding +
      'projects on this device, they will appear here.' + LineEnding + LineEnding +
      'You can start a new project anytime by tapping the' + LineEnding +
      'green button in the top right.';
    WelcomeBody.Color    := Pal.TextPrimary;
    WelcomeBody.FontSize := 14;
    WelcomeBody.MaxWidth := 520 - 64;
    WelcomeBody.Anchor(hpLeft, hpLeft, 32);
    WelcomeBody.Anchor(vpTop,  vpTop,  -68);
    WelcomeCard.InsertFront(WelcomeBody);

    StartBtn          := TCastleButton.Create(FreeAtStop);
    StartBtn.Caption  := 'START A NEW PROJECT';
    StartBtn.FontSize := 14;
    StartBtn.OnClick  := @ClickNewProject;
    StartBtn.CustomBackground    := True;
    StartBtn.CustomColorNormal   := Pal.Primary;
    StartBtn.CustomColorFocused  := Pal.PrimaryDark;
    StartBtn.CustomColorPressed  := Pal.PrimaryDark;
    StartBtn.CustomTextColorUse  := True;
    StartBtn.CustomTextColor     := Pal.TextInverse;
    StartBtn.AutoSize := False;
    StartBtn.Width    := 220;
    StartBtn.Height   := 44;
    StartBtn.Anchor(hpMiddle, hpMiddle);
    StartBtn.Anchor(vpMiddle, vpMiddle, -100);
    FScrollView.ScrollArea.InsertFront(StartBtn);
    Exit;
  end;

  for I := 0 to High(FProjects) do
  begin
    Row        := TCastleRectangleControl.Create(FreeAtStop);
    Row.Color  := Pal.PanelBg;
    Row.Height := RowH;
    Row.Tag    := I;
    FScrollView.ScrollArea.InsertFront(Row);

    NameLbl         := TCastleLabel.Create(FreeAtStop);
    NameLbl.Caption := FProjects[I].BookName + '  (' + FProjects[I].TargetLangCode + ')';
    NameLbl.Color   := Pal.TextPrimary;
    NameLbl.FontSize := 16;
    NameLbl.Anchor(hpLeft, hpLeft, RowPad);
    NameLbl.Anchor(vpTop, vpTop, -14);
    Row.InsertFront(NameLbl);

    DetailLbl         := TCastleLabel.Create(FreeAtStop);
    DetailLbl.Caption :=
      FProjects[I].ResourceType + '  •  ' +
      IntToStr(FProjects[I].FinishedChunks) + ' / ' +
      IntToStr(FProjects[I].TotalChunks) + ' chunks';
    DetailLbl.Color   := Pal.TextSecondary;
    DetailLbl.FontSize := 13;
    DetailLbl.Anchor(hpLeft, hpLeft, RowPad);
    DetailLbl.Anchor(vpBottom, vpBottom, 14);
    Row.InsertFront(DetailLbl);

    { Progress percentage label }
    if FProjects[I].TotalChunks > 0 then
      Pct := Round(FProjects[I].FinishedChunks / FProjects[I].TotalChunks * 100)
    else
      Pct := 0;
    ProgLbl         := TCastleLabel.Create(FreeAtStop);
    ProgLbl.Caption := IntToStr(Pct) + '%';
    ProgLbl.Color   := Pal.Accent;
    ProgLbl.FontSize := 14;
    ProgLbl.Anchor(hpRight, hpRight, -90);
    ProgLbl.Anchor(vpMiddle, vpMiddle);
    Row.InsertFront(ProgLbl);

    Btn           := TCastleButton.Create(FreeAtStop);
    Btn.Caption   := 'Open';
    Btn.FontSize  := 13;
    Btn.Tag       := I;
    Btn.OnClick   := @ClickProject;
    Btn.Anchor(hpRight, hpRight, -RowPad);
    Btn.Anchor(vpMiddle, vpMiddle);
    Row.InsertFront(Btn);
  end;
end;

procedure TViewHome.ClickProject(Sender: TObject);
var
  I: Integer;
begin
  I := (Sender as TCastleButton).Tag;
  if (I < 0) or (I > High(FProjects)) then Exit;

  GAppState.Screen               := asEditor;
  GAppState.Editor.ProjectDir    := FProjects[I].FullPath;
  GAppState.Editor.ProjectTitle  :=
    FProjects[I].BookName + ' — ' + FProjects[I].TargetLangCode;
  GAppState.Editor.BookCode      := FProjects[I].BookCode;
  GAppState.Editor.TargetLangCode := FProjects[I].TargetLangCode;
  GAppState.Editor.ChapterIndex  := 0;
  GAppState.Editor.ChunkIndex    := -1;

  Container.View := ViewEditor;
end;

procedure TViewHome.ClickNewProject(Sender: TObject);
begin
  Container.View := ViewNewProject;
end;

procedure TViewHome.ClickMenu(Sender: TObject);
begin
  FMenuPopup.Exists := not FMenuPopup.Exists;
  FBackdrop.Exists  := FMenuPopup.Exists;
end;

procedure TViewHome.MenuDismiss;
begin
  FMenuPopup.Exists := False;
  FBackdrop.Exists  := False;
end;

procedure TViewHome.MenuUpdateClick(Sender: TObject);
begin
  MenuDismiss;
  LogInfo('Menu: Update selected (stub)');
end;

procedure TViewHome.MenuImportClick(Sender: TObject);
begin
  MenuDismiss;
  Container.View := ViewImport;
end;

procedure TViewHome.MenuAcademyClick(Sender: TObject);
begin
  MenuDismiss;
  LogInfo('Menu: translationAcademy selected (stub)');
end;

procedure TViewHome.MenuFeedbackClick(Sender: TObject);
begin
  MenuDismiss;
  Container.PushView(ViewFeedback);
end;

procedure TViewHome.MenuLogoutClick(Sender: TObject);
begin
  MenuDismiss;
  { Push confirmation dialog; result is handled in Resume. }
  FConfirmLogout := TViewConfirm.Create(Self, 'Log out of BTT-Writer?');
  Container.PushView(FConfirmLogout);
end;

procedure TViewHome.MenuSettingsClick(Sender: TObject);
begin
  MenuDismiss;
  Container.View := ViewSettings;
end;

procedure TViewHome.Resize;
var
  W, H, ContentW: Single;
begin
  inherited;
  if FHeader = nil then Exit;
  W := EffectiveWidth;
  H := EffectiveHeight;
  ContentW := W - BTT_RAIL_W;

  { Header: full width, top }
  FHeader.Translation := Vector2(0, H - BTT_HEADER_H);
  FHeader.Width       := W;
  FHeader.Height      := BTT_HEADER_H;

  { Status bar: full width, bottom }
  FStatusBar.Translation := Vector2(0, 0);
  FStatusBar.Width       := W;
  FStatusBar.Height      := BTT_STATUS_H;

  { Content bar: right of rail, just below header }
  FContentBar.Translation := Vector2(BTT_RAIL_W, H - BTT_HEADER_H - ContentBarH);
  FContentBar.Width       := ContentW;
  FContentBar.Height      := ContentBarH;

  { Rail: left side, above status bar, below header }
  FRail.Translation := Vector2(0, BTT_STATUS_H);
  FRail.Width       := BTT_RAIL_W;
  FRail.Height      := H - BTT_HEADER_H - BTT_STATUS_H;

  { Scroll view: remaining content area below content bar, above status bar }
  FScrollView.Translation := Vector2(BTT_RAIL_W, BTT_STATUS_H);
  FScrollView.Width       := ContentW;
  FScrollView.Height      := H - BTT_HEADER_H - ContentBarH - BTT_STATUS_H;

  { Popup: anchored to bottom-left of content area, extends upward }
  FMenuPopup.Translation := Vector2(BTT_RAIL_W, H - BTT_HEADER_H - FMenuPopup.Height);

  { FAB: top-right of content area, straddling the content-bar edge. }
  FNewProjBtn.Translation := Vector2(
    W - FNewProjBtn.Width - 28,
    H - BTT_HEADER_H - ContentBarH + 4);

  UpdateScrollArea;
end;

procedure TViewHome.UpdateScrollArea;
var
  I: Integer;
  AreaW, TotalH, CurBottom: Single;
  Row: TCastleUserInterface;
begin
  if FScrollView = nil then Exit;

  AreaW := FScrollView.EffectiveWidthForChildren
         - FScrollView.EffectiveScrollBarWidth;

  if Length(FProjects) = 0 then
  begin
    FScrollView.ScrollArea.Width  := AreaW;
    FScrollView.ScrollArea.Height := FScrollView.Height;
    Exit;
  end;

  TotalH := (RowH + RowGap) * Length(FProjects) + RowGap;
  FScrollView.ScrollArea.Width  := AreaW;
  FScrollView.ScrollArea.Height := TotalH;

  CurBottom := TotalH - RowGap;
  for I := 0 to FScrollView.ScrollArea.ControlsCount - 1 do
  begin
    Row := FScrollView.ScrollArea.Controls[I];
    CurBottom      := CurBottom - RowH;
    Row.Translation := Vector2(0, CurBottom);
    Row.Width       := AreaW;
    CurBottom      := CurBottom - RowGap;
  end;
end;

procedure TViewHome.Resume;
begin
  inherited;
  { Returning from the logout confirmation dialog.
    Cannot call Container.View here (lifecycle method) — set a flag instead. }
  if Assigned(FConfirmLogout) then
  begin
    if FConfirmLogout.Answer then
    begin
      GAppState.UserName := '(not logged in)';
      GAppState.IsLocal  := False;
      ClearUserProfile;
      LogInfo('Logout confirmed');
      FPendingLogout := True;
    end;
    FreeAndNil(FConfirmLogout);
  end;
end;

procedure TViewHome.Update(const SecondsPassed: Single; var HandleInput: Boolean);
begin
  inherited;
  if FPendingLogout then
  begin
    FPendingLogout := False;
    Container.View := ViewLogin;
  end;
end;

procedure TViewHome.OnThemeChange;
begin
  if Container <> nil then
    Container.View := Self;
end;

end.
