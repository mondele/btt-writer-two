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

  FNewProjBtn := TCastleButton.Create(FreeAtStop);
  FNewProjBtn.Caption  := '+ New Project';
  FNewProjBtn.FontSize := 13;
  FNewProjBtn.OnClick  := @ClickNewProject;
  FNewProjBtn.Anchor(hpRight, hpRight, -RowPad);
  FNewProjBtn.Anchor(vpMiddle, vpMiddle);
  FContentBar.InsertFront(FNewProjBtn);

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
  FMenuPopup.AddItem('Update',             @MenuUpdateClick);
  FMenuPopup.AddItem('Import ...',         @MenuImportClick);
  FMenuPopup.AddItem('translationAcademy', @MenuAcademyClick);
  FMenuPopup.AddItem('Feedback',           @MenuFeedbackClick);
  FMenuPopup.AddItem('Logout',             @MenuLogoutClick);
  FMenuPopup.AddItem('Settings',           @MenuSettingsClick);
  FMenuPopup.Build;
  InsertFront(FMenuPopup);    { on top of backdrop }
  FBackdrop.Menu := FMenuPopup;
end;

procedure TViewHome.BuildProjectList;
var
  Pal: TBTTPalette;
  I: Integer;
  Row: TCastleRectangleControl;
  NameLbl, DetailLbl, ProgLbl, EmptyLbl: TCastleLabel;
  Btn: TCastleButton;
  Pct: Integer;
begin
  Pal := P;

  if Length(FProjects) = 0 then
  begin
    EmptyLbl := TCastleLabel.Create(FreeAtStop);
    EmptyLbl.Caption :=
      'No translation projects found.' + LineEnding +
      'Projects are stored in:' + LineEnding +
      '~/.config/BTT-Writer/targetTranslations/';
    EmptyLbl.Color     := Pal.TextSecondary;
    EmptyLbl.FontSize  := 15;
    EmptyLbl.Alignment := hpMiddle;
    EmptyLbl.Anchor(hpMiddle, hpMiddle);
    EmptyLbl.Anchor(vpMiddle, vpMiddle);
    FScrollView.ScrollArea.InsertFront(EmptyLbl);
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
