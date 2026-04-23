{$mode objfpc}{$H+}
unit GameViewImport;

{ Import screen for the CGE app.

  Step 0 — Choice: four option cards (server, .tstudio, USFM, source text).
  Step 1 — .tstudio path: text field + Import button + status label.
  Step 2 — Server search: user/book fields + Search + results list + Import.

  USFM and Source Text show a "not yet available" message.

  Duplicate project handling: when the backend returns ioDuplicateExists, a
  three-button overlay (Merge / Overwrite / Cancel) is shown over the current
  step.  The user's choice re-triggers the import with the appropriate action.
}

interface

uses
  Classes,
  CastleUIControls, CastleControls, CastleColors,
  CGEViewBase, BTTHeader, BTTBreadcrumb, BTTStatusBar,
  GiteaClient;   { TGiteaRepoInfo, TGiteaRepoArray }

type
  TViewImport = class(TCGEViewBase)
  private
    { ── Chrome ── }
    FHeader      : TBTTHeader;
    FCrumb       : TBTTBreadcrumb;
    FStatusBar   : TBTTStatusBar;
    FCard        : TCastleRectangleControl;
    FTitleLbl    : TCastleLabel;
    FBackBtn     : TCastleButton;

    { ── Step 0: choice ── }
    FChoicePanel : TCastleRectangleControl;
    FBtnServer   : TCastleButton;
    FBtnTStudio  : TCastleButton;
    FBtnUSFM     : TCastleButton;
    FBtnSource   : TCastleButton;

    { ── Step 1: .tstudio path ── }
    FTStudioPanel : TCastleRectangleControl;
    FPathEdit     : TCastleEdit;
    FImportBtn    : TCastleButton;
    FStatusLbl    : TCastleLabel;

    { ── Step 2: server search ── }
    FServerPanel  : TCastleRectangleControl;
    FUserEdit     : TCastleEdit;
    FBookEdit     : TCastleEdit;
    FSearchBtn    : TCastleButton;
    FSearchStatus : TCastleLabel;
    FListContent  : TComponent;
    FListScroll   : TCastleScrollView;
    FServerImport : TCastleButton;
    FRepos        : TGiteaRepoArray;
    FSelRepoIdx   : Integer;
    FNeedsSearch  : Boolean;

    { ── Step 3: USFM import ── }
    FUSFMPanel    : TCastleRectangleControl;
    FUSFMPathEdit : TCastleEdit;
    FUSFMLangEdit : TCastleEdit;
    FUSFMImportBtn: TCastleButton;
    FUSFMStatusLbl: TCastleLabel;

    { ── Step 4: stub (source text) ── }
    FStubPanel    : TCastleRectangleControl;
    FStubLbl      : TCastleLabel;

    { ── Duplicate overlay ── }
    FDupOverlay   : TCastleRectangleControl;
    FDupMergeBtn  : TCastleButton;
    FDupOverBtn   : TCastleButton;
    FDupCancelBtn : TCastleButton;
    FDupPendingPath : string;    { pending .tstudio path when dup found }
    FDupPendingRepo : Integer;   { pending repo index when dup found     }
    FDupPendingLang : string;    { pending lang code for USFM import     }

    FStep : Integer;  { 0=choice 1=tstudio 2=server 3=usfm 4=stub }

    procedure BuildChrome;
    procedure BuildChoice;
    procedure BuildTStudio;
    procedure BuildServer;
    procedure BuildUSFM;
    procedure BuildStub;
    procedure BuildDupOverlay;

    procedure ShowStep(S: Integer);
    procedure ShowDupOverlay;
    procedure HideDupOverlay;

    procedure SetStatus(const Msg: string; IsError: Boolean = False);
    procedure SetUSFMStatus(const Msg: string; IsError: Boolean = False);
    procedure SetServerStatus(const Msg: string; IsError: Boolean = False);
    procedure RebuildRepoList;

    procedure ClickBack(Sender: TObject);
    procedure ClickServer(Sender: TObject);
    procedure ClickTStudio(Sender: TObject);
    procedure ClickUSFM(Sender: TObject);
    procedure ClickSource(Sender: TObject);
    procedure ClickImportTStudio(Sender: TObject);
    procedure ClickImportUSFM(Sender: TObject);
    procedure ClickSearch(Sender: TObject);
    procedure ClickRepo(Sender: TObject);
    procedure ClickServerImport(Sender: TObject);
    procedure ClickDupMerge(Sender: TObject);
    procedure ClickDupOverwrite(Sender: TObject);
    procedure ClickDupCancel(Sender: TObject);

    procedure DoTStudioImport(const FilePath: string; DupAction: Integer);
    procedure DoServerImport(RepoIdx: Integer; DupAction: Integer);
    procedure DoUSFMImport(const FilePath, LangCode: string; DupAction: Integer);
  public
    procedure Start;    override;
    procedure Update(const SecondsPassed: Single; var HandleInput: Boolean); override;
    procedure Resize;   override;
    procedure OnThemeChange; override;
  end;

var
  ViewImport: TViewImport;

implementation

uses
  SysUtils, Math, CastleVectors,
  AppState, BTTTheme, AppLog,
  UserProfile, AppSettings,
  ProjectImporter,
  GameViewHome;

const
  CardW   = 560;
  CardH   = 460;
  Pad     = 20;
  BtnH    = 44;
  RowH    = 48;
  RowGap  = 4;

{ ── Start ── }

procedure TViewImport.Start;
begin
  inherited;
  ApplyBackground;
  FStep       := 0;
  FNeedsSearch := False;
  FSelRepoIdx := -1;
  FListContent := nil;
  FDupPendingLang := '';
  BuildChrome;
  BuildChoice;
  BuildTStudio;
  BuildServer;
  BuildUSFM;
  BuildStub;
  BuildDupOverlay;
  ShowStep(0);
end;

{ ── Chrome ── }

procedure TViewImport.BuildChrome;
var
  Pal : TBTTPalette;
begin
  Pal := P;

  FHeader := TBTTHeader.Create(FreeAtStop, Pal);
  FHeader.SetTitle('BTT-Writer');
  InsertFront(FHeader);

  FCrumb := TBTTBreadcrumb.Create(FreeAtStop, Pal);
  FCrumb.OnBack := @ClickBack;
  FCrumb.SetCrumbs(['Home', 'Import']);
  InsertFront(FCrumb);

  FStatusBar := TBTTStatusBar.Create(FreeAtStop, Pal);
  InsertFront(FStatusBar);

  FCard        := TCastleRectangleControl.Create(FreeAtStop);
  FCard.Color  := Pal.PanelBg;
  FCard.Width  := CardW;
  FCard.Height := CardH;
  FCard.Anchor(hpMiddle, hpMiddle);
  FCard.Anchor(vpMiddle, vpMiddle);
  InsertFront(FCard);

  FTitleLbl          := TCastleLabel.Create(FreeAtStop);
  FTitleLbl.Caption  := 'Import';
  FTitleLbl.Color    := Pal.TextPrimary;
  FTitleLbl.FontSize := 22;
  FTitleLbl.Anchor(hpMiddle, hpMiddle);
  FTitleLbl.Anchor(vpTop,    vpTop,    -Pad);
  FCard.InsertFront(FTitleLbl);

  FBackBtn          := TCastleButton.Create(FreeAtStop);
  FBackBtn.Caption  := '← Back';
  FBackBtn.FontSize := 13;
  FBackBtn.Width    := 90;
  FBackBtn.OnClick  := @ClickBack;
  FBackBtn.Anchor(hpLeft,  hpLeft,  Pad);
  FBackBtn.Anchor(vpBottom, vpBottom, Pad);
  FCard.InsertFront(FBackBtn);
end;

{ ── Choice panel ── }

procedure TViewImport.BuildChoice;
var
  Pal : TBTTPalette;
  Y   : Single;
begin
  Pal := P;

  FChoicePanel        := TCastleRectangleControl.Create(FreeAtStop);
  FChoicePanel.Color  := Pal.PanelBg;
  FChoicePanel.FullSize := True;
  FChoicePanel.Exists   := False;
  FCard.InsertFront(FChoicePanel);

  Y := CardH - 80;

  FBtnServer          := TCastleButton.Create(FreeAtStop);
  FBtnServer.Caption  := 'Import from Server';
  FBtnServer.FontSize := 15;
  FBtnServer.Width    := CardW - Pad * 2;
  FBtnServer.Height   := BtnH;
  FBtnServer.Translation := CastleVectors.Vector2(Pad, Y);
  FBtnServer.OnClick  := @ClickServer;
  { Disable if user has no server token }
  FBtnServer.Enabled  := not LoadUserProfile.IsLocal;
  FChoicePanel.InsertFront(FBtnServer);
  Y := Y - (BtnH + 10);

  FBtnTStudio          := TCastleButton.Create(FreeAtStop);
  FBtnTStudio.Caption  := 'Import Project File (.tstudio)';
  FBtnTStudio.FontSize := 15;
  FBtnTStudio.Width    := CardW - Pad * 2;
  FBtnTStudio.Height   := BtnH;
  FBtnTStudio.Translation := CastleVectors.Vector2(Pad, Y);
  FBtnTStudio.OnClick  := @ClickTStudio;
  FChoicePanel.InsertFront(FBtnTStudio);
  Y := Y - (BtnH + 10);

  FBtnUSFM          := TCastleButton.Create(FreeAtStop);
  FBtnUSFM.Caption  := 'Import USFM File';
  FBtnUSFM.FontSize := 15;
  FBtnUSFM.Width    := CardW - Pad * 2;
  FBtnUSFM.Height   := BtnH;
  FBtnUSFM.Translation := CastleVectors.Vector2(Pad, Y);
  FBtnUSFM.OnClick  := @ClickUSFM;
  FChoicePanel.InsertFront(FBtnUSFM);
  Y := Y - (BtnH + 10);

  FBtnSource          := TCastleButton.Create(FreeAtStop);
  FBtnSource.Caption  := 'Import Source Text';
  FBtnSource.FontSize := 15;
  FBtnSource.Width    := CardW - Pad * 2;
  FBtnSource.Height   := BtnH;
  FBtnSource.Translation := CastleVectors.Vector2(Pad, Y);
  FBtnSource.OnClick  := @ClickSource;
  FChoicePanel.InsertFront(FBtnSource);
end;

{ ── .tstudio panel ── }

procedure TViewImport.BuildTStudio;
var
  Pal  : TBTTPalette;
  Lbl  : TCastleLabel;
begin
  Pal := P;

  FTStudioPanel        := TCastleRectangleControl.Create(FreeAtStop);
  FTStudioPanel.Color  := Pal.PanelBg;
  FTStudioPanel.FullSize := True;
  FTStudioPanel.Exists   := False;
  FCard.InsertFront(FTStudioPanel);

  Lbl          := TCastleLabel.Create(FreeAtStop);
  Lbl.Caption  := 'Path to .tstudio file:';
  Lbl.Color    := Pal.TextPrimary;
  Lbl.FontSize := 14;
  Lbl.Anchor(hpLeft,  hpLeft,  Pad);
  Lbl.Anchor(vpTop,   vpTop,   -70);
  FTStudioPanel.InsertFront(Lbl);

  FPathEdit             := TCastleEdit.Create(FreeAtStop);
  FPathEdit.Placeholder := '/home/user/project.tstudio';
  FPathEdit.FontSize    := 13;
  FPathEdit.Width       := CardW - Pad * 2;
  FPathEdit.Anchor(hpLeft,  hpLeft,  Pad);
  FPathEdit.Anchor(vpTop,   vpTop,   -100);
  FTStudioPanel.InsertFront(FPathEdit);

  FImportBtn          := TCastleButton.Create(FreeAtStop);
  FImportBtn.Caption  := 'Import';
  FImportBtn.FontSize := 14;
  FImportBtn.Width    := 110;
  FImportBtn.OnClick  := @ClickImportTStudio;
  FImportBtn.Anchor(hpRight,  hpRight,  -Pad);
  FImportBtn.Anchor(vpTop,    vpTop,    -152);
  FTStudioPanel.InsertFront(FImportBtn);

  FStatusLbl          := TCastleLabel.Create(FreeAtStop);
  FStatusLbl.Caption  := '';
  FStatusLbl.Color    := Pal.TextSecondary;
  FStatusLbl.FontSize := 13;
  FStatusLbl.MaxWidth := CardW - Pad * 2;
  FStatusLbl.Anchor(hpLeft,  hpLeft,  Pad);
  FStatusLbl.Anchor(vpTop,   vpTop,   -200);
  FTStudioPanel.InsertFront(FStatusLbl);
end;

{ ── Server search panel ── }

procedure TViewImport.BuildServer;
var
  Pal : TBTTPalette;
  Lbl : TCastleLabel;
begin
  Pal := P;

  FServerPanel        := TCastleRectangleControl.Create(FreeAtStop);
  FServerPanel.Color  := Pal.PanelBg;
  FServerPanel.FullSize := True;
  FServerPanel.Exists   := False;
  FCard.InsertFront(FServerPanel);

  Lbl          := TCastleLabel.Create(FreeAtStop);
  Lbl.Caption  := 'Username:';
  Lbl.Color    := Pal.TextPrimary;
  Lbl.FontSize := 13;
  Lbl.Anchor(hpLeft, hpLeft, Pad);
  Lbl.Anchor(vpTop,  vpTop,  -70);
  FServerPanel.InsertFront(Lbl);

  FUserEdit             := TCastleEdit.Create(FreeAtStop);
  FUserEdit.Placeholder := 'username';
  FUserEdit.FontSize    := 13;
  FUserEdit.Width       := 200;
  FUserEdit.Anchor(hpLeft, hpLeft, Pad);
  FUserEdit.Anchor(vpTop,  vpTop,  -96);
  FServerPanel.InsertFront(FUserEdit);

  Lbl          := TCastleLabel.Create(FreeAtStop);
  Lbl.Caption  := 'Book / language filter (optional):';
  Lbl.Color    := Pal.TextPrimary;
  Lbl.FontSize := 13;
  Lbl.Anchor(hpLeft, hpLeft, Pad + 220);
  Lbl.Anchor(vpTop,  vpTop,  -70);
  FServerPanel.InsertFront(Lbl);

  FBookEdit             := TCastleEdit.Create(FreeAtStop);
  FBookEdit.Placeholder := 'mat / fr';
  FBookEdit.FontSize    := 13;
  FBookEdit.Width       := CardW - Pad * 2 - 220 - 10;
  FBookEdit.Anchor(hpLeft, hpLeft, Pad + 220);
  FBookEdit.Anchor(vpTop,  vpTop,  -96);
  FServerPanel.InsertFront(FBookEdit);

  FSearchBtn          := TCastleButton.Create(FreeAtStop);
  FSearchBtn.Caption  := 'Search';
  FSearchBtn.FontSize := 13;
  FSearchBtn.Width    := 90;
  FSearchBtn.OnClick  := @ClickSearch;
  FSearchBtn.Anchor(hpRight,  hpRight,  -Pad);
  FSearchBtn.Anchor(vpTop,    vpTop,    -140);
  FServerPanel.InsertFront(FSearchBtn);

  FSearchStatus          := TCastleLabel.Create(FreeAtStop);
  FSearchStatus.Caption  := '';
  FSearchStatus.Color    := Pal.TextSecondary;
  FSearchStatus.FontSize := 12;
  FSearchStatus.Anchor(hpLeft, hpLeft, Pad);
  FSearchStatus.Anchor(vpTop,  vpTop,  -142);
  FServerPanel.InsertFront(FSearchStatus);

  { Results list — scroll area }
  FListScroll := TCastleScrollView.Create(FreeAtStop);
  FListScroll.Anchor(hpLeft,   hpLeft,   Pad);
  FListScroll.Anchor(hpRight,  hpRight,  -Pad);
  FListScroll.Anchor(vpBottom, vpBottom, BtnH + Pad + 10);
  FListScroll.Anchor(vpTop,    vpTop,    -160);
  FServerPanel.InsertFront(FListScroll);

  FServerImport          := TCastleButton.Create(FreeAtStop);
  FServerImport.Caption  := 'Import Selected';
  FServerImport.FontSize := 13;
  FServerImport.Width    := 160;
  FServerImport.Enabled  := False;
  FServerImport.OnClick  := @ClickServerImport;
  FServerImport.Anchor(hpRight,  hpRight,  -Pad);
  FServerImport.Anchor(vpBottom, vpBottom, Pad);
  FServerPanel.InsertFront(FServerImport);
end;

{ ── USFM import panel ── }

procedure TViewImport.BuildUSFM;
var
  Pal     : TBTTPalette;
  HintLbl : TCastleLabel;
begin
  Pal := P;

  FUSFMPanel       := TCastleRectangleControl.Create(FreeAtStop);
  FUSFMPanel.Color := Pal.PanelBg;
  FUSFMPanel.FullSize := True;
  FUSFMPanel.Exists   := False;
  FCard.InsertFront(FUSFMPanel);

  HintLbl          := TCastleLabel.Create(FreeAtStop);
  HintLbl.Caption  := 'Enter the full path to the .usfm file:';
  HintLbl.Color    := Pal.TextSecondary;
  HintLbl.FontSize := 13;
  HintLbl.Anchor(hpLeft, hpLeft, Pad);
  HintLbl.Anchor(vpTop,  vpTop,  -Pad);
  FUSFMPanel.InsertFront(HintLbl);

  FUSFMPathEdit             := TCastleEdit.Create(FreeAtStop);
  FUSFMPathEdit.Placeholder := '/path/to/file.usfm';
  FUSFMPathEdit.Width       := CardW - Pad * 2;
  FUSFMPathEdit.FontSize    := 14;
  FUSFMPathEdit.Anchor(hpMiddle, hpMiddle);
  FUSFMPathEdit.Anchor(vpTop,    vpTop,    -(Pad + 30));
  FUSFMPanel.InsertFront(FUSFMPathEdit);

  HintLbl          := TCastleLabel.Create(FreeAtStop);
  HintLbl.Caption  := 'Target language code (e.g. fr, ru, id):';
  HintLbl.Color    := Pal.TextSecondary;
  HintLbl.FontSize := 13;
  HintLbl.Anchor(hpLeft, hpLeft, Pad);
  HintLbl.Anchor(vpTop,  vpTop,  -(Pad + 80));
  FUSFMPanel.InsertFront(HintLbl);

  FUSFMLangEdit             := TCastleEdit.Create(FreeAtStop);
  FUSFMLangEdit.Placeholder := 'Language code';
  FUSFMLangEdit.Width       := 180;
  FUSFMLangEdit.FontSize    := 14;
  FUSFMLangEdit.Anchor(hpLeft, hpLeft, Pad);
  FUSFMLangEdit.Anchor(vpTop, vpTop, -(Pad + 110));
  FUSFMPanel.InsertFront(FUSFMLangEdit);

  FUSFMStatusLbl          := TCastleLabel.Create(FreeAtStop);
  FUSFMStatusLbl.Caption  := '';
  FUSFMStatusLbl.Color    := Pal.TextSecondary;
  FUSFMStatusLbl.FontSize := 13;
  FUSFMStatusLbl.MaxWidth := CardW - Pad * 2;
  FUSFMStatusLbl.Anchor(hpMiddle, hpMiddle);
  FUSFMStatusLbl.Anchor(vpBottom, vpBottom, Pad + BtnH + 8);
  FUSFMPanel.InsertFront(FUSFMStatusLbl);

  FUSFMImportBtn          := TCastleButton.Create(FreeAtStop);
  FUSFMImportBtn.Caption  := 'Import';
  FUSFMImportBtn.FontSize := 14;
  FUSFMImportBtn.Width    := 120;
  FUSFMImportBtn.OnClick  := @ClickImportUSFM;
  FUSFMImportBtn.Anchor(hpRight, hpRight, -Pad);
  FUSFMImportBtn.Anchor(vpBottom, vpBottom, Pad);
  FUSFMPanel.InsertFront(FUSFMImportBtn);
end;

{ ── Stub panel (Source Text) ── }

procedure TViewImport.BuildStub;
var
  Pal : TBTTPalette;
begin
  Pal := P;

  FStubPanel        := TCastleRectangleControl.Create(FreeAtStop);
  FStubPanel.Color  := Pal.PanelBg;
  FStubPanel.FullSize := True;
  FStubPanel.Exists   := False;
  FCard.InsertFront(FStubPanel);

  FStubLbl          := TCastleLabel.Create(FreeAtStop);
  FStubLbl.Caption  := '';
  FStubLbl.Color    := Pal.TextSecondary;
  FStubLbl.FontSize := 15;
  FStubLbl.MaxWidth := CardW - Pad * 4;
  FStubLbl.Alignment := hpMiddle;
  FStubLbl.Anchor(hpMiddle, hpMiddle);
  FStubLbl.Anchor(vpMiddle, vpMiddle);
  FStubPanel.InsertFront(FStubLbl);
end;

{ ── Duplicate overlay ── }

procedure TViewImport.BuildDupOverlay;
var
  Lbl  : TCastleLabel;
begin
  FDupOverlay        := TCastleRectangleControl.Create(FreeAtStop);
  FDupOverlay.Color  := CastleVectors.Vector4(0, 0, 0, 0.72);
  FDupOverlay.FullSize := True;
  FDupOverlay.Exists   := False;
  FCard.InsertFront(FDupOverlay);

  Lbl          := TCastleLabel.Create(FreeAtStop);
  Lbl.Caption  := 'A project with this name already exists.' + LineEnding +
                  'How would you like to proceed?';
  Lbl.Color    := CastleColors.White;
  Lbl.FontSize := 14;
  Lbl.MaxWidth := CardW - Pad * 4;
  Lbl.Alignment := hpMiddle;
  Lbl.Anchor(hpMiddle, hpMiddle);
  Lbl.Anchor(vpMiddle, vpMiddle, 60);
  FDupOverlay.InsertFront(Lbl);

  FDupMergeBtn          := TCastleButton.Create(FreeAtStop);
  FDupMergeBtn.Caption  := 'Merge';
  FDupMergeBtn.FontSize := 14;
  FDupMergeBtn.Width    := 120;
  FDupMergeBtn.OnClick  := @ClickDupMerge;
  FDupMergeBtn.Anchor(hpMiddle, hpMiddle, -140);
  FDupMergeBtn.Anchor(vpMiddle, vpMiddle, -10);
  FDupOverlay.InsertFront(FDupMergeBtn);

  FDupOverBtn          := TCastleButton.Create(FreeAtStop);
  FDupOverBtn.Caption  := 'Overwrite';
  FDupOverBtn.FontSize := 14;
  FDupOverBtn.Width    := 120;
  FDupOverBtn.OnClick  := @ClickDupOverwrite;
  FDupOverBtn.Anchor(hpMiddle, hpMiddle, 0);
  FDupOverBtn.Anchor(vpMiddle, vpMiddle, -10);
  FDupOverlay.InsertFront(FDupOverBtn);

  FDupCancelBtn          := TCastleButton.Create(FreeAtStop);
  FDupCancelBtn.Caption  := 'Cancel';
  FDupCancelBtn.FontSize := 14;
  FDupCancelBtn.Width    := 100;
  FDupCancelBtn.OnClick  := @ClickDupCancel;
  FDupCancelBtn.Anchor(hpMiddle, hpMiddle, 140);
  FDupCancelBtn.Anchor(vpMiddle, vpMiddle, -10);
  FDupOverlay.InsertFront(FDupCancelBtn);
end;

{ ── Step switching ── }

procedure TViewImport.ShowStep(S: Integer);
begin
  FStep := S;
  FChoicePanel.Exists  := (S = 0);
  FTStudioPanel.Exists := (S = 1);
  FServerPanel.Exists  := (S = 2);
  FUSFMPanel.Exists    := (S = 3);
  FStubPanel.Exists    := (S = 4);
  FBackBtn.Exists      := (S > 0);
  case S of
    0: FTitleLbl.Caption := 'Import';
    1: FTitleLbl.Caption := 'Import Project File';
    2: FTitleLbl.Caption := 'Import from Server';
    3: FTitleLbl.Caption := 'Import USFM File';
    4: FTitleLbl.Caption := 'Import';
  end;
end;

procedure TViewImport.ShowDupOverlay;
begin
  FDupOverlay.Exists := True;
end;

procedure TViewImport.HideDupOverlay;
begin
  FDupOverlay.Exists  := False;
  FDupPendingPath     := '';
  FDupPendingRepo     := -1;
  FDupPendingLang     := '';
end;

{ ── Status helpers ── }

procedure TViewImport.SetStatus(const Msg: string; IsError: Boolean);
var
  Pal : TBTTPalette;
begin
  Pal := P;
  FStatusLbl.Caption := Msg;
  if IsError then
    FStatusLbl.Color := CastleVectors.Vector4(0.85, 0.2, 0.2, 1)
  else
    FStatusLbl.Color := Pal.TextSecondary;
end;

procedure TViewImport.SetUSFMStatus(const Msg: string; IsError: Boolean);
var
  Pal : TBTTPalette;
begin
  Pal := P;
  FUSFMStatusLbl.Caption := Msg;
  if IsError then
    FUSFMStatusLbl.Color := CastleVectors.Vector4(0.85, 0.2, 0.2, 1)
  else
    FUSFMStatusLbl.Color := Pal.TextSecondary;
end;

procedure TViewImport.SetServerStatus(const Msg: string; IsError: Boolean);
var
  Pal : TBTTPalette;
begin
  Pal := P;
  FSearchStatus.Caption := Msg;
  if IsError then
    FSearchStatus.Color := CastleVectors.Vector4(0.85, 0.2, 0.2, 1)
  else
    FSearchStatus.Color := Pal.TextSecondary;
end;

{ ── Repo list rebuild ── }

procedure TViewImport.RebuildRepoList;
var
  Pal   : TBTTPalette;
  I     : Integer;
  Row   : TCastleRectangleControl;
  Lbl   : TCastleLabel;
  Btn   : TCastleButton;
  TotalH, CurBottom : Single;
  AreaW : Single;
begin
  Pal := P;
  FSelRepoIdx := -1;
  FServerImport.Enabled := False;

  { Free previous list — freeing the component owner cascade-frees all rows,
    which removes them from the scroll area automatically. }
  FreeAndNil(FListContent);
  FListContent := TComponent.Create(FreeAtStop);

  if Length(FRepos) = 0 then
  begin
    FListScroll.ScrollArea.Width  := FListScroll.Width;
    FListScroll.ScrollArea.Height := FListScroll.Height;
    Exit;
  end;

  AreaW  := FListScroll.EffectiveWidthForChildren;
  TotalH := RowGap + (RowH + RowGap) * Length(FRepos);

  FListScroll.ScrollArea.Width  := AreaW;
  FListScroll.ScrollArea.Height := Max(FListScroll.Height, TotalH);

  CurBottom := Max(FListScroll.Height, TotalH) - RowGap;
  for I := 0 to High(FRepos) do
  begin
    CurBottom := CurBottom - RowH;
    Row        := TCastleRectangleControl.Create(FListContent);
    Row.Color  := Pal.ContentBg;
    Row.Width  := AreaW;
    Row.Height := RowH;
    Row.Translation := CastleVectors.Vector2(0, CurBottom);
    Row.Tag    := I;
    FListScroll.ScrollArea.InsertFront(Row);

    Lbl          := TCastleLabel.Create(FListContent);
    Lbl.Caption  := FRepos[I].FullName;
    Lbl.Color    := Pal.TextPrimary;
    Lbl.FontSize := 13;
    Lbl.Anchor(hpLeft,   hpLeft,   8);
    Lbl.Anchor(vpMiddle, vpMiddle);
    Row.InsertFront(Lbl);

    Btn          := TCastleButton.Create(FListContent);
    Btn.Caption  := '';
    Btn.CustomBackground := True;
    Btn.FullSize := True;
    Btn.Tag      := I;
    Btn.OnClick  := @ClickRepo;
    Row.InsertFront(Btn);

    CurBottom := CurBottom - RowGap;
  end;
end;

{ ── Click handlers ── }

procedure TViewImport.ClickBack(Sender: TObject);
begin
  if FDupOverlay.Exists then
  begin
    HideDupOverlay;
    Exit;
  end;
  ShowStep(0);
end;

procedure TViewImport.ClickServer(Sender: TObject);
begin
  ShowStep(2);
end;

procedure TViewImport.ClickTStudio(Sender: TObject);
begin
  FPathEdit.Text := '';
  SetStatus('');
  ShowStep(1);
end;

procedure TViewImport.ClickUSFM(Sender: TObject);
begin
  FUSFMPathEdit.Text := '';
  FUSFMLangEdit.Text := '';
  SetUSFMStatus('');
  ShowStep(3);
end;

procedure TViewImport.ClickSource(Sender: TObject);
begin
  FStubLbl.Caption :=
    'Source texts are managed through the New Project flow.' + LineEnding + LineEnding +
    'Return to Home and use "+ New Project" to add a source text.';
  ShowStep(4);
end;

procedure TViewImport.DoTStudioImport(const FilePath: string; DupAction: Integer);
var
  ProjName, ErrMsg : string;
  Outcome          : TImportOutcome;
begin
  SetStatus('Importing...');
  FImportBtn.Enabled := False;

  Outcome := ImportTStudioFile(FilePath, TDuplicateAction(DupAction),
    ProjName, ErrMsg);

  FImportBtn.Enabled := True;
  case Outcome of
    ioSuccess:
    begin
      SetStatus('Imported: ' + ProjName);
      LogInfo('Import: .tstudio imported as ' + ProjName);
    end;
    ioMergedWithConflicts:
    begin
      SetStatus('Merged with conflicts: ' + ProjName +
        '. Open the project to resolve.', True);
    end;
    ioDuplicateExists:
    begin
      FDupPendingPath := FilePath;
      FDupPendingRepo := -1;
      ShowDupOverlay;
    end;
    ioError:
      SetStatus(ErrMsg, True);
  end;
end;

procedure TViewImport.ClickImportTStudio(Sender: TObject);
var
  FilePath : string;
begin
  FilePath := Trim(FPathEdit.Text);
  if FilePath = '' then
  begin
    SetStatus('Please enter the path to the .tstudio file.', True);
    Exit;
  end;
  if not FileExists(FilePath) then
  begin
    SetStatus('File not found: ' + FilePath, True);
    Exit;
  end;
  DoTStudioImport(FilePath, Ord(daNone));
end;

procedure TViewImport.ClickImportUSFM(Sender: TObject);
var
  FilePath, LangCode : string;
begin
  FilePath := Trim(FUSFMPathEdit.Text);
  LangCode := Trim(FUSFMLangEdit.Text);
  if FilePath = '' then
  begin
    SetUSFMStatus('Please enter the path to the .usfm file.', True);
    Exit;
  end;
  if not FileExists(FilePath) then
  begin
    SetUSFMStatus('File not found: ' + FilePath, True);
    Exit;
  end;
  if LangCode = '' then
  begin
    SetUSFMStatus('Please enter a target language code.', True);
    Exit;
  end;
  DoUSFMImport(FilePath, LangCode, Ord(daNone));
end;

procedure TViewImport.DoUSFMImport(const FilePath, LangCode: string; DupAction: Integer);
var
  ProjName, ErrMsg : string;
  Outcome          : TImportOutcome;
begin
  SetUSFMStatus('Importing...');
  FUSFMImportBtn.Enabled := False;

  Outcome := ImportUSFMFile(FilePath, LangCode, TDuplicateAction(DupAction),
    ProjName, ErrMsg);

  FUSFMImportBtn.Enabled := True;
  case Outcome of
    ioSuccess:
    begin
      SetUSFMStatus('Imported: ' + ProjName);
      LogInfo('Import: USFM imported as ' + ProjName);
    end;
    ioMergedWithConflicts:
    begin
      SetUSFMStatus('Merged with conflicts: ' + ProjName +
        '. Open the project to resolve.', True);
    end;
    ioDuplicateExists:
    begin
      FDupPendingPath := FilePath;
      FDupPendingLang := LangCode;
      FDupPendingRepo := -1;
      ShowDupOverlay;
    end;
    ioError:
      SetUSFMStatus(ErrMsg, True);
  end;
end;

procedure TViewImport.ClickSearch(Sender: TObject);
begin
  if (Trim(FUserEdit.Text) = '') and (Trim(FBookEdit.Text) = '') then
  begin
    SetServerStatus('Enter a username or book/language code.', True);
    Exit;
  end;
  FSelRepoIdx := -1;
  FServerImport.Enabled := False;
  SetServerStatus('Searching...');
  FNeedsSearch := True;
end;

procedure TViewImport.ClickRepo(Sender: TObject);
var
  Idx : Integer;
  Pal : TBTTPalette;
  I   : Integer;
  Ctrl: TCastleUserInterface;
  Row : TCastleRectangleControl;
begin
  Idx := (Sender as TCastleButton).Tag;
  Pal := P;

  { Recolour rows }
  for I := 0 to FListScroll.ScrollArea.ControlsCount - 1 do
  begin
    Ctrl := FListScroll.ScrollArea.Controls[I];
    if Ctrl is TCastleRectangleControl then
    begin
      Row := TCastleRectangleControl(Ctrl);
      if Row.Tag = Idx then
        Row.Color := Pal.PrimaryLight
      else
        Row.Color := Pal.ContentBg;
    end;
  end;

  FSelRepoIdx           := Idx;
  FServerImport.Enabled := True;
end;

procedure TViewImport.DoServerImport(RepoIdx: Integer; DupAction: Integer);
var
  Profile          : TUserProfile;
  SrvURL, Token    : string;
  ProjName, ErrMsg : string;
  Outcome          : TImportOutcome;
begin
  if (RepoIdx < 0) or (RepoIdx >= Length(FRepos)) then Exit;

  SetServerStatus('Cloning and importing...');
  FServerImport.Enabled := False;

  Profile := LoadUserProfile;
  SrvURL  := Profile.ServerURL;
  if SrvURL = '' then SrvURL := DefaultDataServerURL;
  Token   := Profile.Token;

  Outcome := CloneAndImport(FRepos[RepoIdx].CloneURL, Token,
    TDuplicateAction(DupAction), ProjName, ErrMsg);

  FServerImport.Enabled := FSelRepoIdx >= 0;
  case Outcome of
    ioSuccess:
    begin
      SetServerStatus('Imported: ' + ProjName);
      LogInfo('Import: server repo imported as ' + ProjName);
    end;
    ioMergedWithConflicts:
      SetServerStatus('Merged with conflicts: ' + ProjName +
        '. Open the project to resolve.', True);
    ioDuplicateExists:
    begin
      FDupPendingPath := '';
      FDupPendingRepo := RepoIdx;
      ShowDupOverlay;
    end;
    ioError:
      SetServerStatus(ErrMsg, True);
  end;
end;

procedure TViewImport.ClickServerImport(Sender: TObject);
begin
  DoServerImport(FSelRepoIdx, Ord(daNone));
end;

procedure TViewImport.ClickDupMerge(Sender: TObject);
var
  PendingPath, PendingLang: string;
  PendingRepo: Integer;
begin
  PendingPath := FDupPendingPath;
  PendingLang := FDupPendingLang;
  PendingRepo := FDupPendingRepo;
  HideDupOverlay;
  if (PendingPath <> '') and (PendingLang <> '') then
    DoUSFMImport(PendingPath, PendingLang, Ord(daMerge))
  else if PendingPath <> '' then
    DoTStudioImport(PendingPath, Ord(daMerge))
  else if PendingRepo >= 0 then
    DoServerImport(PendingRepo, Ord(daMerge));
end;

procedure TViewImport.ClickDupOverwrite(Sender: TObject);
var
  PendingPath, PendingLang: string;
  PendingRepo: Integer;
begin
  PendingPath := FDupPendingPath;
  PendingLang := FDupPendingLang;
  PendingRepo := FDupPendingRepo;
  HideDupOverlay;
  if (PendingPath <> '') and (PendingLang <> '') then
    DoUSFMImport(PendingPath, PendingLang, Ord(daOverwrite))
  else if PendingPath <> '' then
    DoTStudioImport(PendingPath, Ord(daOverwrite))
  else if PendingRepo >= 0 then
    DoServerImport(PendingRepo, Ord(daOverwrite));
end;

procedure TViewImport.ClickDupCancel(Sender: TObject);
begin
  HideDupOverlay;
end;

{ ── Update: deferred search ── }

procedure TViewImport.Update(const SecondsPassed: Single; var HandleInput: Boolean);
var
  Profile       : TUserProfile;
  SrvURL, Token : string;
  ErrMsg, Query : string;
begin
  inherited;
  if not FNeedsSearch then Exit;
  FNeedsSearch := False;

  Profile := LoadUserProfile;
  SrvURL  := Profile.ServerURL;
  if SrvURL = '' then SrvURL := DefaultDataServerURL;
  Token   := Profile.Token;

  ErrMsg := '';
  Query  := Trim(FUserEdit.Text);
  if Query <> '' then
    GiteaListUserRepos(SrvURL, Token, Query, 50, FRepos, ErrMsg)
  else
    GiteaSearchRepos(SrvURL, Token, Trim(FBookEdit.Text), 50, FRepos, ErrMsg);

  if ErrMsg <> '' then
    SetServerStatus(ErrMsg, True)
  else if Length(FRepos) = 0 then
    SetServerStatus('No repositories found.')
  else
    SetServerStatus(IntToStr(Length(FRepos)) + ' result(s)');

  RebuildRepoList;
end;

{ ── Layout ── }

procedure TViewImport.Resize;
var
  W, H: Single;
begin
  inherited;
  if FHeader = nil then Exit;
  W := EffectiveWidth;
  H := EffectiveHeight;

  FHeader.Translation := CastleVectors.Vector2(0, H - BTT_HEADER_H);
  FHeader.Width       := W;
  FHeader.Height      := BTT_HEADER_H;

  FCrumb.Translation := CastleVectors.Vector2(0, H - BTT_HEADER_H - BTT_BREADCRUMB_H);
  FCrumb.Width       := W;
  FCrumb.Height      := BTT_BREADCRUMB_H;

  FStatusBar.Translation := CastleVectors.Vector2(0, 0);
  FStatusBar.Width       := W;
  FStatusBar.Height      := BTT_STATUS_H;
  { Card centres itself via anchors. }
end;

procedure TViewImport.OnThemeChange;
begin
  if Container <> nil then
    Container.View := Self;
end;

end.
