{$mode objfpc}{$H+}
unit GameViewBlindEdit;

{ Blind Edit mode — Phase 5.

  Shows one chunk at a time.  The translator reads the source text, then
  flips to a blank card and types their translation from memory.  Source and
  translation are never visible simultaneously.

  Card metaphor:
    FFrontCard   — the card currently shown (source text or translation text)
    FShadowCard  — a slightly offset rectangle giving a "stacked card" feel
    FPeekTab     — strip below the front card; click to flip source↔translation

  Navigation:
    Prev / Next chunk — sequential across chapters (chapter wraps silently).
    GAppState.Editor.ChapterIndex / ChunkIndex track position.

  Editing:
    Clicking "Edit" on the translation card pushes TViewChunkEdit.
    Resume saves the returned text back via TChunk.Content + SaveContent.
}

interface

uses
  Classes,
  CastleUIControls, CastleControls, CastleColors,
  CGEViewBase, BTTHeader;

type
  TViewBlindEdit = class(TCGEViewBase)
  private
    { ── chrome ── }
    FHeader       : TBTTHeader;
    FNavBar       : TCastleRectangleControl;
    FPrevChunkBtn : TCastleButton;
    FNextChunkBtn : TCastleButton;
    FChunkInfoLbl : TCastleLabel;
    FCardArea     : TCastleRectangleControl;
    FShadowCard   : TCastleRectangleControl;
    FFrontCard    : TCastleRectangleControl;
    FCardLbl      : TCastleLabel;
    FEmptyLbl     : TCastleLabel;   { "No translation yet" placeholder }
    FEditBtn      : TCastleButton;
    FPeekTab      : TCastleButton;

    { ── data ── (freed in Stop) }
    FProject      : TObject;   { TProject }
    FSource       : TObject;   { TResourceContainer }
    FHasSource    : Boolean;
    FChapterCount : Integer;

    { ── state ── }
    FShowingSource : Boolean;
    FNeedsRelayout : Boolean;

    { ── editing ── }
    FChunkEdit : TObject;  { TViewChunkEdit while editing }

    procedure BuildChrome;
    procedure LoadProjectData;
    procedure LoadChunkContent;
    procedure UpdateNavBar;
    procedure UpdateCardContent;
    procedure UpdateCardHeight;

    procedure ClickBack(Sender: TObject);
    procedure ClickReadMode(Sender: TObject);
    procedure ClickPrevChunk(Sender: TObject);
    procedure ClickNextChunk(Sender: TObject);
    procedure ClickFlip(Sender: TObject);
    procedure ClickEdit(Sender: TObject);

    function  CurrentChunkCount: Integer;
    procedure StepChunk(Delta: Integer);
  public
    procedure Start;  override;
    procedure Stop;   override;
    procedure Resume; override;
    procedure Resize; override;
    procedure Update(const SecondsPassed: Single;
                     var HandleInput: Boolean); override;
    procedure OnThemeChange; override;
  end;

var
  ViewBlindEdit: TViewBlindEdit;

implementation

uses
  SysUtils, Math, CastleVectors,
  AppState, BTTTheme, AppLog,
  DataPaths, ProjectManager, ResourceContainer, ProjectScanner,
  BibleBook, BibleChapter,
  USFMRenderer,
  GameViewHome, GameViewEditor, GameViewChunkEdit;

const
  NavBarH     = 44;
  CardPad     = 16;
  ShadowOff   = 6;   { shadow card offset }
  PeekTabH    = 40;
  CardRadius  = 0;   { no rounded corners for now }
  VerseColor  = '#888888';

{ ── helpers ────────────────────────────────────────────────────────────────── }

function ProjectRef(V: TViewBlindEdit): TProject; inline;
begin Result := TProject(V.FProject); end;

function SourceRef(V: TViewBlindEdit): TResourceContainer; inline;
begin Result := TResourceContainer(V.FSource); end;

{ ── TViewBlindEdit ──────────────────────────────────────────────────────────── }

function TViewBlindEdit.CurrentChunkCount: Integer;
var
  ChIdx: Integer;
begin
  Result := 0;
  if (FProject = nil) or (ProjectRef(Self).Book = nil) then Exit;
  ChIdx := GAppState.Editor.ChapterIndex;
  if (ChIdx < 0) or (ChIdx >= FChapterCount) then Exit;
  Result := ProjectRef(Self).Book.Chapters[ChIdx].Chunks.Count;
end;

procedure TViewBlindEdit.StepChunk(Delta: Integer);
var
  ChIdx, CkIdx, CkCount: Integer;
begin
  ChIdx  := GAppState.Editor.ChapterIndex;
  CkIdx  := GAppState.Editor.ChunkIndex;
  CkCount := CurrentChunkCount;

  CkIdx := CkIdx + Delta;

  if CkIdx < 0 then
  begin
    { Wrap to last chunk of previous chapter }
    if ChIdx > 0 then
    begin
      Dec(ChIdx);
      GAppState.Editor.ChapterIndex := ChIdx;
      GAppState.Editor.ChunkIndex   :=
        ProjectRef(Self).Book.Chapters[ChIdx].Chunks.Count - 1;
    end;
  end
  else if CkIdx >= CkCount then
  begin
    { Wrap to first chunk of next chapter }
    if ChIdx < FChapterCount - 1 then
    begin
      Inc(ChIdx);
      GAppState.Editor.ChapterIndex := ChIdx;
      GAppState.Editor.ChunkIndex   := 0;
    end;
  end
  else
    GAppState.Editor.ChunkIndex := CkIdx;
end;

procedure TViewBlindEdit.Start;
begin
  inherited;
  ApplyBackground;
  FShowingSource := True;
  FChunkEdit     := nil;
  BuildChrome;
  LoadProjectData;
  if GAppState.Editor.ChunkIndex < 0 then
    GAppState.Editor.ChunkIndex := 0;
  LoadChunkContent;
end;

procedure TViewBlindEdit.Stop;
begin
  FChunkEdit := nil;
  if FProject <> nil then TProject(FProject).Free;
  FProject := nil;
  if FSource <> nil then TResourceContainer(FSource).Free;
  FSource := nil;
  inherited;
end;

procedure TViewBlindEdit.BuildChrome;
var
  Pal     : TBTTPalette;
  BackBtn : TCastleButton;
  ReadBtn : TCastleButton;
begin
  Pal := P;

  { Header }
  FHeader := TBTTHeader.Create(FreeAtStop, Pal);
  FHeader.SetTitle(GAppState.Editor.ProjectTitle);
  InsertFront(FHeader);

  BackBtn         := TCastleButton.Create(FreeAtStop);
  BackBtn.Caption := '< Home';
  BackBtn.FontSize := 14;
  BackBtn.OnClick := @ClickBack;
  FHeader.AddLeft(BackBtn);

  ReadBtn         := TCastleButton.Create(FreeAtStop);
  ReadBtn.Caption := 'Read';
  ReadBtn.FontSize := 13;
  ReadBtn.OnClick := @ClickReadMode;
  FHeader.AddRight(ReadBtn);

  { Navigation bar }
  FNavBar       := TCastleRectangleControl.Create(FreeAtStop);
  FNavBar.Color := Pal.ContentBg;
  InsertFront(FNavBar);

  FPrevChunkBtn         := TCastleButton.Create(FreeAtStop);
  FPrevChunkBtn.Caption := '< Chunk';
  FPrevChunkBtn.FontSize := 13;
  FPrevChunkBtn.OnClick := @ClickPrevChunk;
  FPrevChunkBtn.Anchor(hpLeft,  hpLeft,  12);
  FPrevChunkBtn.Anchor(vpMiddle, vpMiddle);
  FNavBar.InsertFront(FPrevChunkBtn);

  FNextChunkBtn         := TCastleButton.Create(FreeAtStop);
  FNextChunkBtn.Caption := 'Chunk >';
  FNextChunkBtn.FontSize := 13;
  FNextChunkBtn.OnClick := @ClickNextChunk;
  FNextChunkBtn.Anchor(hpRight,  hpRight,  -12);
  FNextChunkBtn.Anchor(vpMiddle, vpMiddle);
  FNavBar.InsertFront(FNextChunkBtn);

  FChunkInfoLbl         := TCastleLabel.Create(FreeAtStop);
  FChunkInfoLbl.Caption := 'Loading...';
  FChunkInfoLbl.Color   := Pal.TextSecondary;
  FChunkInfoLbl.FontSize := 13;
  FChunkInfoLbl.Anchor(hpMiddle, hpMiddle);
  FChunkInfoLbl.Anchor(vpMiddle, vpMiddle);
  FNavBar.InsertFront(FChunkInfoLbl);

  { Card area }
  FCardArea       := TCastleRectangleControl.Create(FreeAtStop);
  FCardArea.Color := Pal.WindowBg;
  InsertFront(FCardArea);

  { Shadow card — drawn first (behind front card) }
  FShadowCard       := TCastleRectangleControl.Create(FreeAtStop);
  FShadowCard.Color := Pal.ContentBg;
  FCardArea.InsertFront(FShadowCard);

  { Front card }
  FFrontCard       := TCastleRectangleControl.Create(FreeAtStop);
  FFrontCard.Color := Pal.PanelBg;
  FCardArea.InsertFront(FFrontCard);

  FCardLbl          := TCastleLabel.Create(FreeAtStop);
  FCardLbl.Html     := True;
  FCardLbl.Color    := Pal.TextPrimary;
  FCardLbl.FontSize := 15;
  FCardLbl.Anchor(hpLeft, hpLeft,  CardPad);
  FCardLbl.Anchor(vpTop,  vpTop,  -CardPad);
  FFrontCard.InsertFront(FCardLbl);

  { Empty translation placeholder }
  FEmptyLbl          := TCastleLabel.Create(FreeAtStop);
  FEmptyLbl.Caption  := 'No translation yet.';
  FEmptyLbl.Html     := False;
  FEmptyLbl.Color    := Pal.TextSecondary;
  FEmptyLbl.FontSize := 15;
  FEmptyLbl.Anchor(hpMiddle, hpMiddle);
  FEmptyLbl.Anchor(vpMiddle, vpMiddle);
  FEmptyLbl.Exists   := False;
  FFrontCard.InsertFront(FEmptyLbl);

  { Edit button on front card (visible in translation mode) }
  FEditBtn          := TCastleButton.Create(FreeAtStop);
  FEditBtn.Caption  := 'Edit';
  FEditBtn.FontSize := 13;
  FEditBtn.OnClick  := @ClickEdit;
  FEditBtn.Anchor(hpRight,  hpRight,  -CardPad);
  FEditBtn.Anchor(vpBottom, vpBottom,  CardPad);
  FEditBtn.Exists   := False;
  FFrontCard.InsertFront(FEditBtn);

  { Peek tab — a button styled as a flat strip }
  FPeekTab                   := TCastleButton.Create(FreeAtStop);
  FPeekTab.Caption           := 'Show Translation';
  FPeekTab.FontSize          := 13;
  FPeekTab.OnClick           := @ClickFlip;
  FPeekTab.CustomBackground  := True;
  FCardArea.InsertFront(FPeekTab);
end;

procedure TViewBlindEdit.LoadProjectData;
var
  Summary   : TProjectSummary;
  SrcContDir: string;
  SrcDirName, SrcLang, SrcBook, SrcRes: string;
begin
  FProject := nil;
  FSource  := nil;
  FHasSource    := False;
  FChapterCount := 0;

  if GAppState.Editor.ProjectDir = '' then Exit;

  FProject := TProject.Create(GAppState.Editor.ProjectDir);

  Summary := Default(TProjectSummary);
  Summary.BookCode     := ProjectRef(Self).BookCode;
  Summary.ResourceType := ProjectRef(Self).ResourceType;
  SrcContDir := FindSourceContentDir(Summary);
  if SrcContDir = '' then
    SrcContDir := FindEnglishULBContentDir(ProjectRef(Self).BookCode);

  if SrcContDir <> '' then
  begin
    ProjectRef(Self).LoadContent(SrcContDir);
    SrcDirName := ExtractFileName(
      ExcludeTrailingPathDelimiter(
        ExtractFilePath(ExcludeTrailingPathDelimiter(SrcContDir))));
    if TResourceContainer.ParseDirName(SrcDirName, SrcLang, SrcBook, SrcRes) then
    begin
      FSource := TResourceContainer.Create(SrcLang, SrcBook, SrcRes,
        ExcludeTrailingPathDelimiter(
          ExtractFilePath(ExcludeTrailingPathDelimiter(SrcContDir))));
      SourceRef(Self).Load;
      FHasSource := True;
    end;
  end
  else
    LogInfo('BlindEdit: source not found for ' + ProjectRef(Self).BookCode);

  if ProjectRef(Self).Book <> nil then
    FChapterCount := ProjectRef(Self).Book.Chapters.Count
  else
    FChapterCount := 0;

  if GAppState.Editor.ChapterIndex >= FChapterCount then
    GAppState.Editor.ChapterIndex := 0;
end;

procedure TViewBlindEdit.LoadChunkContent;
begin
  FShowingSource := True;
  UpdateNavBar;
  UpdateCardContent;
  FNeedsRelayout := True;
end;

procedure TViewBlindEdit.UpdateNavBar;
var
  ChIdx, CkIdx, CkCount, TotalChunks, I: Integer;
  Ch: TChapter;
begin
  if FChunkInfoLbl = nil then Exit;

  ChIdx  := GAppState.Editor.ChapterIndex;
  CkIdx  := GAppState.Editor.ChunkIndex;
  CkCount := CurrentChunkCount;

  { Count total chunks traversed so far for a "global" chunk label }
  TotalChunks := 0;
  if (FProject <> nil) and (ProjectRef(Self).Book <> nil) then
    for I := 0 to ChIdx - 1 do
    begin
      Ch := ProjectRef(Self).Book.Chapters[I];
      TotalChunks := TotalChunks + Ch.Chunks.Count;
    end;

  FChunkInfoLbl.Caption :=
    'Ch ' + IntToStr(ChIdx + 1) + '  Chunk ' +
    IntToStr(CkIdx + 1)  + ' / ' + IntToStr(CkCount);

  { Disable prev at very start, next at very end }
  FPrevChunkBtn.Exists :=
    (CkIdx > 0) or (ChIdx > 0);
  FNextChunkBtn.Exists :=
    (CkIdx < CkCount - 1) or (ChIdx < FChapterCount - 1);
end;

procedure TViewBlindEdit.UpdateCardContent;
var
  ChIdx, CkIdx  : Integer;
  Chapter       : TChapter;
  SrcChapter    : TChapter;
  TransText     : string;
  SrcText       : string;
  HasTrans      : Boolean;
begin
  if FFrontCard = nil then Exit;

  ChIdx := GAppState.Editor.ChapterIndex;
  CkIdx := GAppState.Editor.ChunkIndex;

  if (FProject = nil) or (ProjectRef(Self).Book = nil) or
     (ChIdx < 0) or (ChIdx >= FChapterCount) then
  begin
    FCardLbl.Caption := '<i>(no data)</i>';
    FCardLbl.Exists  := True;
    FEmptyLbl.Exists := False;
    FEditBtn.Exists  := False;
    Exit;
  end;

  Chapter := ProjectRef(Self).Book.Chapters[ChIdx];
  if (CkIdx < 0) or (CkIdx >= Chapter.Chunks.Count) then
  begin
    FCardLbl.Caption := '<i>(no chunk)</i>';
    FCardLbl.Exists  := True;
    FEmptyLbl.Exists := False;
    FEditBtn.Exists  := False;
    Exit;
  end;

  { Source text }
  SrcChapter := nil;
  if FHasSource and (FSource <> nil) and (SourceRef(Self).Book <> nil) then
    if ChIdx < SourceRef(Self).Book.Chapters.Count then
      SrcChapter := SourceRef(Self).Book.Chapters[ChIdx];

  if (SrcChapter <> nil) and (CkIdx < SrcChapter.Chunks.Count) then
    SrcText := UsxToRichText(SrcChapter.Chunks[CkIdx].Content, VerseColor)
  else
    SrcText := '<i>(no source text)</i>';

  { Translation text }
  TransText := USFMToRichText(Chapter.Chunks[CkIdx].Content, VerseColor);
  HasTrans  := Trim(Chapter.Chunks[CkIdx].Content) <> '';

  if FShowingSource then
  begin
    FCardLbl.Caption  := SrcText;
    FCardLbl.Exists   := True;
    FEmptyLbl.Exists  := False;
    FEditBtn.Exists   := False;
    FPeekTab.Caption  := 'Show Translation';
    FFrontCard.Color  := P.PanelBg;
    FShadowCard.Color := P.ContentBg;
  end
  else
  begin
    if HasTrans then
    begin
      FCardLbl.Caption  := TransText;
      FCardLbl.Exists   := True;
      FEmptyLbl.Exists  := False;
    end
    else
    begin
      FCardLbl.Caption := '';
      FCardLbl.Exists  := False;
      FEmptyLbl.Exists := True;
    end;
    FEditBtn.Exists  := True;
    FPeekTab.Caption := 'Show Source';
    FFrontCard.Color := P.PanelBg;
    FShadowCard.Color := P.ContentBg;
  end;
end;

procedure TViewBlindEdit.UpdateCardHeight;
var
  AreaW, AreaH    : Single;
  CardW, CardH    : Single;
  LblH            : Single;
  CardLeft, CardTop: Single;
begin
  if FCardArea = nil then Exit;
  AreaW := FCardArea.EffectiveWidth;
  AreaH := FCardArea.EffectiveHeight;
  if (AreaW < 1) or (AreaH < 1) then Exit;

  CardW := AreaW - CardPad * 2;
  if CardW < 1 then CardW := 1;

  FCardLbl.MaxWidth := CardW - CardPad * 2;

  if FCardLbl.Exists then
    LblH := FCardLbl.EffectiveHeight
  else
    LblH := 60;  { placeholder height when showing empty label }

  CardH := LblH + CardPad * 2 + 36;  { 36 for edit button row }
  CardH := Max(CardH, 120);

  { Position cards: centered horizontally, top-padded }
  CardLeft := CardPad;
  CardTop  := AreaH - CardPad - CardH;  { CGE: y=0 at bottom }

  { Shadow card slightly offset }
  FShadowCard.Translation := Vector2(CardLeft + ShadowOff, CardTop - ShadowOff);
  FShadowCard.Width       := CardW;
  FShadowCard.Height      := CardH;

  { Front card }
  FFrontCard.Translation := Vector2(CardLeft, CardTop);
  FFrontCard.Width       := CardW;
  FFrontCard.Height      := CardH;

  { Peek tab: below cards, full card area width }
  FPeekTab.Translation := Vector2(0, CardTop - ShadowOff - PeekTabH - 4);
  FPeekTab.Width       := AreaW;
  FPeekTab.Height      := PeekTabH;
end;

procedure TViewBlindEdit.ClickBack(Sender: TObject);
begin
  GAppState.Screen := asHome;
  ResetEditorState;
  Container.View := ViewHome;
end;

procedure TViewBlindEdit.ClickReadMode(Sender: TObject);
begin
  Container.View := ViewEditor;
end;

procedure TViewBlindEdit.ClickPrevChunk(Sender: TObject);
begin
  StepChunk(-1);
  LoadChunkContent;
end;

procedure TViewBlindEdit.ClickNextChunk(Sender: TObject);
begin
  StepChunk(1);
  LoadChunkContent;
end;

procedure TViewBlindEdit.ClickFlip(Sender: TObject);
begin
  FShowingSource := not FShowingSource;
  UpdateCardContent;
  FNeedsRelayout := True;
end;

procedure TViewBlindEdit.ClickEdit(Sender: TObject);
var
  ChIdx, CkIdx: Integer;
  Chapter: TChapter;
begin
  ChIdx := GAppState.Editor.ChapterIndex;
  CkIdx := GAppState.Editor.ChunkIndex;
  if (FProject = nil) or (ProjectRef(Self).Book = nil) then Exit;
  if (ChIdx < 0) or (ChIdx >= FChapterCount) then Exit;
  Chapter := ProjectRef(Self).Book.Chapters[ChIdx];
  if (CkIdx < 0) or (CkIdx >= Chapter.Chunks.Count) then Exit;

  ViewChunkEdit.InputText := Chapter.Chunks[CkIdx].Content;
  FChunkEdit := ViewChunkEdit;
  Container.PushView(ViewChunkEdit);
end;

procedure TViewBlindEdit.Resume;
var
  Edit   : TViewChunkEdit;
  ChIdx, CkIdx: Integer;
  Chapter: TChapter;
begin
  inherited;
  if FChunkEdit = nil then Exit;
  Edit       := TViewChunkEdit(FChunkEdit);
  FChunkEdit := nil;

  if Edit.Answered and not Edit.Cancelled then
  begin
    ChIdx := GAppState.Editor.ChapterIndex;
    CkIdx := GAppState.Editor.ChunkIndex;
    if (FProject <> nil) and (ProjectRef(Self).Book <> nil) and
       (ChIdx >= 0) and (ChIdx < FChapterCount) then
    begin
      Chapter := ProjectRef(Self).Book.Chapters[ChIdx];
      if (CkIdx >= 0) and (CkIdx < Chapter.Chunks.Count) then
      begin
        Chapter.Chunks[CkIdx].Content := Edit.Answer;
        ProjectRef(Self).SaveContent;
        LogInfo('BlindEdit: saved chunk ' + IntToStr(CkIdx));
      end;
    end;
    FShowingSource := False;  { stay on translation card after edit }
    UpdateCardContent;
    FNeedsRelayout := True;
  end;
end;

procedure TViewBlindEdit.Resize;
var
  W, H, ContentH: Single;
begin
  inherited;
  if FHeader = nil then Exit;
  W := EffectiveWidth;
  H := EffectiveHeight;
  ContentH := H - BTT_HEADER_H - NavBarH;

  FHeader.Translation := Vector2(0, H - BTT_HEADER_H);
  FHeader.Width       := W;
  FHeader.Height      := BTT_HEADER_H;

  FNavBar.Translation := Vector2(0, H - BTT_HEADER_H - NavBarH);
  FNavBar.Width       := W;
  FNavBar.Height      := NavBarH;

  FCardArea.Translation := Vector2(0, 0);
  FCardArea.Width       := W;
  FCardArea.Height      := ContentH;

  FNeedsRelayout := True;
end;

procedure TViewBlindEdit.Update(const SecondsPassed: Single;
  var HandleInput: Boolean);
begin
  inherited;
  if FNeedsRelayout then
  begin
    FNeedsRelayout := False;
    UpdateCardHeight;
  end;
end;

procedure TViewBlindEdit.OnThemeChange;
begin
  if Container <> nil then
    Container.View := Self;
end;

end.
