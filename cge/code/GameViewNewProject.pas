{$mode objfpc}{$H+}
unit GameViewNewProject;

{ New Project creation wizard — 3-step CGE view.
  Step 1: pick target language (searchable list)
  Step 2: pick Bible book (OT / NT toggle)
  Step 3: pick source text
  Step 4: create project + result

  Entry: Container.View := ViewNewProject (from Home).
  Exit:  on success → opens ViewEditor with new project;
         on cancel  → Container.View := ViewHome. }

interface

uses
  Classes,
  CastleUIControls, CastleControls, CastleColors, CastleVectors,
  CGEViewBase, BTTHeader,
  ProjectData;

type
  TViewNewProject = class(TCGEViewBase)
  private
    { Chrome (created once in BuildChrome) }
    FHeader      : TBTTHeader;
    FSubBar      : TCastleRectangleControl;
    FFilterEdit  : TCastleEdit;
    FOTBtn       : TCastleButton;
    FNTBtn       : TCastleButton;
    FScrollView  : TCastleScrollView;
    FBotBar      : TCastleRectangleControl;
    FSelLbl      : TCastleLabel;
    FNextBtn     : TCastleButton;
    FStatusLbl   : TCastleLabel;

    { List item owner — freed to clear scroll area }
    FListContent : TComponent;

    { Step data }
    FStep            : Integer;
    FLanguages       : TTargetLanguageOptionList;
    FBooks           : TBookOptionList;
    FSources         : TSourceTextOptionList;
    FVisLangIdx      : array of Integer;   { visible language indices }
    FOTBookIdx       : array of Integer;   { OT book indices }
    FNTBookIdx       : array of Integer;   { NT book indices }
    FSelLangRow      : Integer;            { selected row in visible list }
    FSelBookRow      : Integer;
    FSelSourceRow    : Integer;
    FShowingOT       : Boolean;
    FFilterStr       : string;
    FNeedsListLayout : Boolean;
    FNeedsCreate     : Boolean;

    { Chosen values }
    FLangCode        : string;
    FLangName        : string;
    FBookCode        : string;
    FBookName        : string;
    FSourceOpt       : TSourceTextOption;
    FProjectDir      : string;

    procedure BuildChrome;
    procedure ShowStep(AStep: Integer);
    procedure PopulateLanguageList;
    procedure PopulateBookList;
    procedure PopulateSourceList;
    procedure ClearListRows;
    procedure AddListRow(const ACaption: string; ATag: Integer;
                         ASelected: Boolean);
    procedure LayoutListRows;
    procedure UpdateSubBar;
    procedure UpdateBottomBar;
    procedure DoCreateProject;

    procedure ClickBack(Sender: TObject);
    procedure ClickNext(Sender: TObject);
    procedure ClickOT(Sender: TObject);
    procedure ClickNT(Sender: TObject);
    procedure ClickRow(Sender: TObject);
    procedure ClickOpenProject(Sender: TObject);
    procedure ClickDone(Sender: TObject);
  public
    procedure Start;  override;
    procedure Resize; override;
    procedure Update(const SecondsPassed: Single;
                     var HandleInput: Boolean); override;
    procedure OnThemeChange; override;
  end;

var
  ViewNewProject: TViewNewProject;

implementation

uses
  SysUtils, Math,
  AppState, BTTTheme, AppLog, CanonBooks, ProjectScanner,
  GameViewHome, GameViewEditor;

const
  RowH    = 56;
  RowGap  = 2;
  RowPad  = 16;
  SubBarH = 52;
  BotBarH = 64;

{ ── TViewNewProject ──────────────────────────────────────────────────────── }

procedure TViewNewProject.Start;
var
  I: Integer;
  IsOT: Boolean;
  OTCnt, NTCnt: Integer;
begin
  inherited;
  ApplyBackground;

  FLanguages := ListTargetLanguagesFromIndex;
  FBooks     := ListBooksFromIndex;
  SetLength(FSources, 0);

  { Pre-build OT/NT index arrays for books }
  OTCnt := 0;
  NTCnt := 0;
  for I := 0 to High(FBooks) do
  begin
    if CanonicalBookIsOT(FBooks[I].Code, IsOT) and IsOT then
    begin
      SetLength(FOTBookIdx, OTCnt + 1);
      FOTBookIdx[OTCnt] := I;
      Inc(OTCnt);
    end
    else
    begin
      SetLength(FNTBookIdx, NTCnt + 1);
      FNTBookIdx[NTCnt] := I;
      Inc(NTCnt);
    end;
  end;

  FSelLangRow   := -1;
  FSelBookRow   := -1;
  FSelSourceRow := -1;
  FShowingOT    := True;
  FFilterStr    := '';
  FLangCode     := '';
  FLangName     := '';
  FBookCode     := '';
  FBookName     := '';
  FProjectDir   := '';

  BuildChrome;
  ShowStep(1);
end;

procedure TViewNewProject.BuildChrome;
var
  Pal    : TBTTPalette;
  BackBtn: TCastleButton;
begin
  Pal := P;

  FHeader := TBTTHeader.Create(FreeAtStop, Pal);
  FHeader.SetTitle('New Project');
  InsertFront(FHeader);

  BackBtn         := TCastleButton.Create(FreeAtStop);
  BackBtn.Caption := '< Back';
  BackBtn.FontSize := 14;
  BackBtn.OnClick := @ClickBack;
  FHeader.AddLeft(BackBtn);

  { Sub-bar: holds filter edit (step 1) or OT/NT buttons (step 2) }
  FSubBar       := TCastleRectangleControl.Create(FreeAtStop);
  FSubBar.Color := Pal.ContentBg;
  InsertFront(FSubBar);

  FFilterEdit             := TCastleEdit.Create(FreeAtStop);
  FFilterEdit.Placeholder := 'Filter by language code…';
  FFilterEdit.FontSize    := 14;
  FFilterEdit.Anchor(hpLeft,   hpLeft,   RowPad);
  FFilterEdit.Anchor(vpMiddle, vpMiddle);
  FFilterEdit.Width := 340;
  FSubBar.InsertFront(FFilterEdit);

  FOTBtn         := TCastleButton.Create(FreeAtStop);
  FOTBtn.Caption := 'Old Testament';
  FOTBtn.FontSize := 14;
  FOTBtn.OnClick := @ClickOT;
  FOTBtn.Anchor(hpLeft, hpLeft, RowPad);
  FOTBtn.Anchor(vpMiddle, vpMiddle);
  FSubBar.InsertFront(FOTBtn);

  FNTBtn         := TCastleButton.Create(FreeAtStop);
  FNTBtn.Caption := 'New Testament';
  FNTBtn.FontSize := 14;
  FNTBtn.OnClick := @ClickNT;
  FNTBtn.Anchor(hpLeft, hpLeft, RowPad + 160);
  FNTBtn.Anchor(vpMiddle, vpMiddle);
  FSubBar.InsertFront(FNTBtn);

  { Scroll view for list }
  FScrollView := TCastleScrollView.Create(FreeAtStop);
  InsertFront(FScrollView);

  { Bottom bar: selection info + Next/Create button }
  FBotBar       := TCastleRectangleControl.Create(FreeAtStop);
  FBotBar.Color := Pal.ContentBg;
  InsertFront(FBotBar);

  FSelLbl          := TCastleLabel.Create(FreeAtStop);
  FSelLbl.Caption  := 'Nothing selected';
  FSelLbl.Color    := Pal.TextSecondary;
  FSelLbl.FontSize := 13;
  FSelLbl.Anchor(hpLeft,   hpLeft,   RowPad);
  FSelLbl.Anchor(vpMiddle, vpMiddle);
  FBotBar.InsertFront(FSelLbl);

  FNextBtn         := TCastleButton.Create(FreeAtStop);
  FNextBtn.Caption := 'Next >';
  FNextBtn.FontSize := 14;
  FNextBtn.OnClick := @ClickNext;
  FNextBtn.Anchor(hpRight, hpRight, -RowPad);
  FNextBtn.Anchor(vpMiddle, vpMiddle);
  FBotBar.InsertFront(FNextBtn);

  { Status label for step 4 (creation result) }
  FStatusLbl          := TCastleLabel.Create(FreeAtStop);
  FStatusLbl.Caption  := '';
  FStatusLbl.Color    := P.TextPrimary;
  FStatusLbl.FontSize := 15;
  FStatusLbl.MaxWidth := 700;
  FStatusLbl.Anchor(hpMiddle, hpMiddle);
  FStatusLbl.Anchor(vpMiddle, vpMiddle);
  FStatusLbl.Exists   := False;
  InsertFront(FStatusLbl);

  FListContent := TComponent.Create(FreeAtStop);
end;

{ ── List helpers ─────────────────────────────────────────────────────────── }

procedure TViewNewProject.ClearListRows;
begin
  FreeAndNil(FListContent);
  FListContent := TComponent.Create(FreeAtStop);
end;

procedure TViewNewProject.AddListRow(const ACaption: string; ATag: Integer;
  ASelected: Boolean);
var
  Pal    : TBTTPalette;
  Row    : TCastleRectangleControl;
  Lbl    : TCastleLabel;
  Btn    : TCastleButton;
  RowColor: TCastleColor;
begin
  Pal := P;
  if ASelected then
    RowColor := Pal.Accent
  else
    RowColor := Pal.PanelBg;

  Row       := TCastleRectangleControl.Create(FListContent);
  Row.Color := RowColor;
  Row.Height := RowH;
  FScrollView.ScrollArea.InsertFront(Row);

  Lbl          := TCastleLabel.Create(FListContent);
  Lbl.Caption  := ACaption;
  Lbl.Color    := Pal.TextPrimary;
  Lbl.FontSize := 14;
  Lbl.Anchor(hpLeft,   hpLeft,   RowPad);
  Lbl.Anchor(vpMiddle, vpMiddle);
  Row.InsertFront(Lbl);

  { Transparent full-size button to capture clicks }
  Btn                    := TCastleButton.Create(FListContent);
  Btn.FullSize           := True;
  Btn.CustomBackground   := True;
  Btn.Tag                := ATag;
  Btn.OnClick            := @ClickRow;
  Row.InsertFront(Btn);
end;

procedure TViewNewProject.LayoutListRows;
var
  AreaW, TotalH, CurBottom: Single;
  I: Integer;
  Row: TCastleUserInterface;
  Count: Integer;
begin
  if FScrollView = nil then Exit;
  AreaW := FScrollView.EffectiveWidthForChildren
         - FScrollView.EffectiveScrollBarWidth;
  Count := FScrollView.ScrollArea.ControlsCount;
  if Count = 0 then
  begin
    FScrollView.ScrollArea.Width  := AreaW;
    FScrollView.ScrollArea.Height := FScrollView.Height;
    Exit;
  end;

  TotalH := (RowH + RowGap) * Count + RowGap;
  FScrollView.ScrollArea.Width  := AreaW;
  FScrollView.ScrollArea.Height := Max(FScrollView.Height, TotalH);

  CurBottom := TotalH - RowGap;
  for I := 0 to Count - 1 do
  begin
    Row := FScrollView.ScrollArea.Controls[I];
    CurBottom      := CurBottom - RowH;
    Row.Translation := Vector2(0, CurBottom);
    Row.Width       := AreaW;
    CurBottom      := CurBottom - RowGap;
  end;
end;

{ ── Step population ──────────────────────────────────────────────────────── }

procedure TViewNewProject.PopulateLanguageList;
var
  I, Count: Integer;
  Needle, Caption: string;
begin
  ClearListRows;
  SetLength(FVisLangIdx, 0);
  Count := 0;
  Needle := LowerCase(Trim(FFilterStr));

  for I := 0 to High(FLanguages) do
  begin
    if (Needle <> '') and
       (Pos(Needle, LowerCase(FLanguages[I].Code)) = 0) and
       (Pos(Needle, LowerCase(FLanguages[I].Name)) = 0) then
      Continue;
    SetLength(FVisLangIdx, Count + 1);
    FVisLangIdx[Count] := I;
    Inc(Count);
  end;

  for I := 0 to Count - 1 do
  begin
    Caption := FLanguages[FVisLangIdx[I]].Code + '  —  ' +
               FLanguages[FVisLangIdx[I]].Name;
    AddListRow(Caption, I, I = FSelLangRow);
  end;

  FNeedsListLayout := True;
end;

procedure TViewNewProject.PopulateBookList;
var
  IdxArr: array of Integer;
  I: Integer;
  Caption: string;
begin
  ClearListRows;
  if FShowingOT then
    IdxArr := FOTBookIdx
  else
    IdxArr := FNTBookIdx;

  for I := 0 to High(IdxArr) do
  begin
    Caption := FBooks[IdxArr[I]].Code + '  —  ' + FBooks[IdxArr[I]].Name;
    AddListRow(Caption, I, I = FSelBookRow);
  end;

  FNeedsListLayout := True;
end;

procedure TViewNewProject.PopulateSourceList;
var
  I: Integer;
  Caption: string;
begin
  ClearListRows;
  for I := 0 to High(FSources) do
  begin
    Caption := FSources[I].SourceLangCode + '  —  ' + FSources[I].SourceLangName +
               '    |    ' + FSources[I].ResourceID + '  —  ' + FSources[I].ResourceName;
    AddListRow(Caption, I, I = FSelSourceRow);
  end;
  FNeedsListLayout := True;
end;

{ ── ShowStep ─────────────────────────────────────────────────────────────── }

procedure TViewNewProject.ShowStep(AStep: Integer);
var
  J: Integer;
begin
  FStep := AStep;
  FScrollView.Exists := AStep < 4;
  FSubBar.Exists     := AStep < 4;
  FBotBar.Exists     := True;
  FStatusLbl.Exists  := AStep = 4;

  UpdateSubBar;

  case AStep of
    1: begin
         FHeader.SetTitle('New Project — Step 1/3: Target Language');
         PopulateLanguageList;
         UpdateBottomBar;
       end;
    2: begin
         FHeader.SetTitle('New Project — Step 2/3: Book');
         PopulateBookList;
         UpdateBottomBar;
       end;
    3: begin
         FHeader.SetTitle('New Project — Step 3/3: Source Text');
         FSources      := ListSourceTextOptionsForBookFromIndex(FBookCode);
         { Pre-select en/ulb if present }
         FSelSourceRow := -1;
         if Length(FSources) > 0 then
         begin
           FSelSourceRow := 0;
           { Prefer en/ulb }
           for J := 0 to High(FSources) do
             if (LowerCase(FSources[J].SourceLangCode) = 'en') and
                (LowerCase(FSources[J].ResourceID)     = 'ulb') then
             begin
               FSelSourceRow := J;
               Break;
             end;
         end;
         PopulateSourceList;
         UpdateBottomBar;
       end;
    4: begin
         FHeader.SetTitle('New Project — Creating…');
         FBotBar.Exists    := False;
         FStatusLbl.Exists := True;
         FStatusLbl.Caption := 'Creating project, please wait…';
         FNeedsCreate := True;
       end;
  end;
end;

procedure TViewNewProject.UpdateSubBar;
begin
  FFilterEdit.Exists := FStep = 1;
  FOTBtn.Exists      := FStep = 2;
  FNTBtn.Exists      := FStep = 2;
end;

procedure TViewNewProject.UpdateBottomBar;
var
  HasSel: Boolean;
begin
  case FStep of
    1: begin
         HasSel := FSelLangRow >= 0;
         if HasSel then
           FSelLbl.Caption := 'Selected: ' + FLanguages[FVisLangIdx[FSelLangRow]].Name +
                              ' (' + FLanguages[FVisLangIdx[FSelLangRow]].Code + ')'
         else
           FSelLbl.Caption := 'Select a target language';
         FNextBtn.Caption := 'Next >';
         FNextBtn.Exists  := True;
       end;
    2: begin
         HasSel := FSelBookRow >= 0;
         if HasSel then
         begin
           if FShowingOT then
             FSelLbl.Caption := 'Selected: ' + FBooks[FOTBookIdx[FSelBookRow]].Name
           else
             FSelLbl.Caption := 'Selected: ' + FBooks[FNTBookIdx[FSelBookRow]].Name;
         end
         else
           FSelLbl.Caption := 'Select a Bible book';
         FNextBtn.Caption := 'Next >';
         FNextBtn.Exists  := True;
       end;
    3: begin
         HasSel := FSelSourceRow >= 0;
         if HasSel then
           FSelLbl.Caption := 'Source: ' + FSources[FSelSourceRow].SourceLangCode +
                              ' / ' + FSources[FSelSourceRow].ResourceID
         else
           FSelLbl.Caption := 'Select a source text';
         FNextBtn.Caption := 'Create Project';
         FNextBtn.Exists  := True;
       end;
  end;
end;

{ ── Creation ─────────────────────────────────────────────────────────────── }

procedure TViewNewProject.DoCreateProject;
var
  ErrMsg    : string;
  SuccessBtn: TCastleButton;
  DoneBtn   : TCastleButton;
  Pal       : TBTTPalette;
begin
  Pal := P;
  LogInfo('NewProject: creating ' + FLangCode + '/' + FBookCode + '/' +
          FSourceOpt.ResourceID);

  if not CreateProjectFromSource(FLangCode, FLangName, FSourceOpt, ptText,
                                  FProjectDir, ErrMsg) then
  begin
    FStatusLbl.Caption := 'Error creating project:' + LineEnding + ErrMsg;
    FStatusLbl.Color   := Vector4(0.85, 0.2, 0.2, 1);

    DoneBtn         := TCastleButton.Create(FreeAtStop);
    DoneBtn.Caption := 'Back';
    DoneBtn.FontSize := 14;
    DoneBtn.OnClick := @ClickDone;
    DoneBtn.Anchor(hpMiddle, hpMiddle);
    DoneBtn.Anchor(vpMiddle, vpMiddle, -80);
    InsertFront(DoneBtn);
    Exit;
  end;

  FStatusLbl.Caption := 'Project created successfully!' + LineEnding +
                        FProjectDir;
  FStatusLbl.Color   := Pal.TextPrimary;

  SuccessBtn         := TCastleButton.Create(FreeAtStop);
  SuccessBtn.Caption := 'Open Project';
  SuccessBtn.FontSize := 15;
  SuccessBtn.OnClick := @ClickOpenProject;
  SuccessBtn.Anchor(hpMiddle, hpMiddle, -80);
  SuccessBtn.Anchor(vpMiddle, vpMiddle, -80);
  InsertFront(SuccessBtn);

  DoneBtn         := TCastleButton.Create(FreeAtStop);
  DoneBtn.Caption := 'Done';
  DoneBtn.FontSize := 15;
  DoneBtn.OnClick := @ClickDone;
  DoneBtn.Anchor(hpMiddle, hpMiddle, 80);
  DoneBtn.Anchor(vpMiddle, vpMiddle, -80);
  InsertFront(DoneBtn);
end;

{ ── Button handlers ──────────────────────────────────────────────────────── }

procedure TViewNewProject.ClickBack(Sender: TObject);
begin
  if FStep <= 1 then
    Container.View := ViewHome
  else if FStep = 4 then
    Container.View := ViewHome
  else
    ShowStep(FStep - 1);
end;

procedure TViewNewProject.ClickNext(Sender: TObject);
begin
  case FStep of
    1: begin
         if FSelLangRow < 0 then Exit;
         FLangCode := FLanguages[FVisLangIdx[FSelLangRow]].Code;
         FLangName := FLanguages[FVisLangIdx[FSelLangRow]].Name;
         ShowStep(2);
       end;
    2: begin
         if FSelBookRow < 0 then Exit;
         if FShowingOT then
         begin
           FBookCode := FBooks[FOTBookIdx[FSelBookRow]].Code;
           FBookName := FBooks[FOTBookIdx[FSelBookRow]].Name;
         end
         else
         begin
           FBookCode := FBooks[FNTBookIdx[FSelBookRow]].Code;
           FBookName := FBooks[FNTBookIdx[FSelBookRow]].Name;
         end;
         ShowStep(3);
       end;
    3: begin
         if FSelSourceRow < 0 then Exit;
         FSourceOpt := FSources[FSelSourceRow];
         ShowStep(4);
       end;
  end;
end;

procedure TViewNewProject.ClickOT(Sender: TObject);
begin
  if FShowingOT then Exit;
  FShowingOT  := True;
  FSelBookRow := -1;
  PopulateBookList;
  UpdateBottomBar;
end;

procedure TViewNewProject.ClickNT(Sender: TObject);
begin
  if not FShowingOT then Exit;
  FShowingOT  := False;
  FSelBookRow := -1;
  PopulateBookList;
  UpdateBottomBar;
end;

procedure TViewNewProject.ClickRow(Sender: TObject);
var
  RowIdx   : Integer;
  I        : Integer;
  RowCtrl  : TCastleRectangleControl;
  Pal      : TBTTPalette;
begin
  Pal    := P;
  RowIdx := (Sender as TCastleButton).Tag;

  case FStep of
    1: FSelLangRow   := RowIdx;
    2: FSelBookRow   := RowIdx;
    3: FSelSourceRow := RowIdx;
  end;

  { Recolor rows }
  for I := 0 to FScrollView.ScrollArea.ControlsCount - 1 do
  begin
    RowCtrl := FScrollView.ScrollArea.Controls[I] as TCastleRectangleControl;
    if I = RowIdx then
      RowCtrl.Color := Pal.Accent
    else
      RowCtrl.Color := Pal.PanelBg;
  end;

  UpdateBottomBar;
end;

procedure TViewNewProject.ClickOpenProject(Sender: TObject);
var
  Scan : TProjectSummaryList;
  I    : Integer;
begin
  { Find the newly created project in the scan and open it }
  Scan := ScanProjects;
  for I := 0 to High(Scan) do
    if Scan[I].FullPath = FProjectDir then
    begin
      GAppState.Screen               := asEditor;
      GAppState.Editor.ProjectDir    := Scan[I].FullPath;
      GAppState.Editor.ProjectTitle  :=
        Scan[I].BookName + ' — ' + Scan[I].TargetLangCode;
      GAppState.Editor.BookCode      := Scan[I].BookCode;
      GAppState.Editor.TargetLangCode := Scan[I].TargetLangCode;
      GAppState.Editor.ChapterIndex  := 0;
      GAppState.Editor.ChunkIndex    := -1;
      Container.View := ViewEditor;
      Exit;
    end;
  { Fallback: just go home so the project list refreshes }
  Container.View := ViewHome;
end;

procedure TViewNewProject.ClickDone(Sender: TObject);
begin
  Container.View := ViewHome;
end;

{ ── Layout ───────────────────────────────────────────────────────────────── }

procedure TViewNewProject.Resize;
var
  W, H, ContentY, ContentH: Single;
begin
  inherited;
  if FHeader = nil then Exit;
  W := EffectiveWidth;
  H := EffectiveHeight;

  FHeader.Translation := Vector2(0, H - BTT_HEADER_H);
  FHeader.Width       := W;
  FHeader.Height      := BTT_HEADER_H;

  FSubBar.Translation := Vector2(0, H - BTT_HEADER_H - SubBarH);
  FSubBar.Width       := W;
  FSubBar.Height      := SubBarH;

  FBotBar.Translation := Vector2(0, 0);
  FBotBar.Width       := W;
  FBotBar.Height      := BotBarH;

  ContentY := BotBarH;
  ContentH := H - BTT_HEADER_H - SubBarH - BotBarH;
  if FStep = 4 then
    ContentH := H - BTT_HEADER_H;

  FScrollView.Translation := Vector2(0, ContentY);
  FScrollView.Width       := W;
  FScrollView.Height      := ContentH;

  FNeedsListLayout := True;
end;

procedure TViewNewProject.Update(const SecondsPassed: Single;
  var HandleInput: Boolean);
var
  NewFilter: string;
begin
  inherited;

  { Track filter text changes (step 1) }
  if (FStep = 1) and (FFilterEdit <> nil) then
  begin
    NewFilter := FFilterEdit.Text;
    if NewFilter <> FFilterStr then
    begin
      FFilterStr    := NewFilter;
      FSelLangRow   := -1;
      PopulateLanguageList;
      UpdateBottomBar;
    end;
  end;

  if FNeedsListLayout then
  begin
    FNeedsListLayout := False;
    LayoutListRows;
  end;

  if FNeedsCreate then
  begin
    FNeedsCreate := False;
    DoCreateProject;
  end;
end;

procedure TViewNewProject.OnThemeChange;
begin
  if Container <> nil then
    Container.View := Self;
end;

end.
