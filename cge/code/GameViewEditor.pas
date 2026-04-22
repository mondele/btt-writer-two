{$mode objfpc}{$H+}
unit GameViewEditor;

{ Read-mode editor view — Phase 4 / Phase 5.
  Displays a chapter's source or translation text as rich CGE labels.
  Navigation: prev/next chapter buttons below the header.
  Toggle: source ↔ translation via a header-right button.
  Chapter content is rebuilt via LoadChapterContent without a full view
  restart; only project data is loaded once in Start.

  Phase 5: Translation chunks are shown as individual cards with Edit
  buttons.  Clicking Edit pushes TViewChunkEdit (full-screen); the edited
  text is saved back to the chunk and persisted in Resume.

  Layout (top-to-bottom):
    BTTHeader  (60 px)   — Back button, project+chapter title, mode toggle
    ChapterBar (44 px)   — Prev / Next chapter navigation
    ScrollView (rest)    — content cards (translation) or single label (source)
}

interface

uses
  Classes,
  CastleUIControls, CastleControls, CastleColors,
  CGEViewBase, BTTHeader;

type
  TViewEditor = class(TCGEViewBase)
  private
    { ── chrome ── }
    FHeader      : TBTTHeader;
    FToggleBtn   : TCastleButton;
    FChapterBar  : TCastleRectangleControl;
    FChInfoLbl   : TCastleLabel;
    FPrevBtn     : TCastleButton;
    FNextBtn     : TCastleButton;
    FScrollView  : TCastleScrollView;

    { ── data ── (freed in Stop, NOT by FreeAtStop) }
    FProject     : TObject;  { TProject — typed as TObject to avoid LCL pull }
    FSource      : TObject;  { TResourceContainer }
    FHasSource   : Boolean;
    FChapterCount: Integer;
    FShowSource  : Boolean;

    { ── per-chapter content ── }
    FChapterContent  : TComponent;  { owns the current chapter's cards/labels }
    FNeedsRelayout   : Boolean;

    { ── editing ── }
    FChunkEdit       : TObject;  { TViewChunkEdit instance while editing }
    FEditingChunkIdx : Integer;

    procedure BuildChrome;
    procedure LoadProjectData;
    procedure LoadChapterContent;
    procedure UpdateChapterInfo;
    procedure UpdateScrollHeight;

    procedure ClickBack(Sender: TObject);
    procedure ClickBlindEdit(Sender: TObject);
    procedure ClickToggle(Sender: TObject);
    procedure ClickPrev(Sender: TObject);
    procedure ClickNext(Sender: TObject);
    procedure ClickEditChunk(Sender: TObject);
  public
    procedure Start;  override;
    procedure Stop;   override;
    procedure Resume; override;
    procedure Resize; override;
    procedure Update(const SecondsPassed: Single; var HandleInput: Boolean); override;
    procedure OnThemeChange; override;
  end;

var
  ViewEditor: TViewEditor;

implementation

uses
  SysUtils, Math, CastleVectors,
  AppState, BTTTheme, AppLog,
  DataPaths, ProjectManager, ResourceContainer, ProjectScanner,
  BibleBook, BibleChapter,
  USFMRenderer,
  GameViewHome, GameViewChunkEdit, GameViewBlindEdit;

const
  ChapterBarH  = 44;
  ContentPad   = 16;
  ChunkCardPad = 12;
  ChunkCardGap = 8;
  EditBtnH     = 28;

{ ── helpers ─────────────────────────────────────────────────────────────────── }

function ProjectRef(V: TViewEditor): TProject; inline;
begin
  Result := TProject(V.FProject);
end;

function SourceRef(V: TViewEditor): TResourceContainer; inline;
begin
  Result := TResourceContainer(V.FSource);
end;

{ ── TViewEditor ─────────────────────────────────────────────────────────────── }

procedure TViewEditor.Start;
begin
  inherited;
  ApplyBackground;
  FShowSource      := False;
  FEditingChunkIdx := -1;
  FChunkEdit       := nil;
  BuildChrome;
  LoadProjectData;
  LoadChapterContent;
end;

procedure TViewEditor.Stop;
begin
  FreeAndNil(FChapterContent);
  if FProject <> nil then TProject(FProject).Free;
  FProject := nil;
  if FSource <> nil then TResourceContainer(FSource).Free;
  FSource := nil;
  FChunkEdit := nil;  { owned by CGE view stack — do not free here }
  inherited;
end;

procedure TViewEditor.Resume;
var
  Edit    : TViewChunkEdit;
  ChIdx   : Integer;
  Chapter : TChapter;
begin
  inherited;

  if FChunkEdit = nil then Exit;
  Edit := TViewChunkEdit(FChunkEdit);
  FChunkEdit := nil;

  if Edit.Answered and not Edit.Cancelled then
  begin
    if (FProject <> nil) and (TProject(FProject).Book <> nil) then
    begin
      ChIdx := GAppState.Editor.ChapterIndex;
      if (ChIdx >= 0) and (ChIdx < FChapterCount) then
      begin
        Chapter := TProject(FProject).Book.Chapters[ChIdx];
        if (FEditingChunkIdx >= 0) and
           (FEditingChunkIdx < Chapter.Chunks.Count) then
        begin
          Chapter.Chunks[FEditingChunkIdx].Content := Edit.Answer;
          TProject(FProject).SaveContent;
          LogInfo('Editor: saved chunk ' + IntToStr(FEditingChunkIdx));
        end;
      end;
    end;
    LoadChapterContent;  { refresh display }
  end;
  FEditingChunkIdx := -1;
end;

procedure TViewEditor.BuildChrome;
var
  Pal      : TBTTPalette;
  BackBtn  : TCastleButton;
  BlindBtn : TCastleButton;
begin
  Pal := P;

  { Header }
  FHeader := TBTTHeader.Create(FreeAtStop, Pal);
  FHeader.SetTitle(GAppState.Editor.ProjectTitle);
  InsertFront(FHeader);

  { Chapter bar }
  FChapterBar       := TCastleRectangleControl.Create(FreeAtStop);
  FChapterBar.Color := Pal.ContentBg;
  InsertFront(FChapterBar);

  FPrevBtn          := TCastleButton.Create(FreeAtStop);
  FPrevBtn.Caption  := '<';
  FPrevBtn.FontSize := 16;
  FPrevBtn.OnClick  := @ClickPrev;
  FPrevBtn.Anchor(hpLeft, hpLeft, 12);
  FPrevBtn.Anchor(vpMiddle, vpMiddle);
  FChapterBar.InsertFront(FPrevBtn);

  FNextBtn          := TCastleButton.Create(FreeAtStop);
  FNextBtn.Caption  := '>';
  FNextBtn.FontSize := 16;
  FNextBtn.OnClick  := @ClickNext;
  FNextBtn.Anchor(hpRight, hpRight, -12);
  FNextBtn.Anchor(vpMiddle, vpMiddle);
  FChapterBar.InsertFront(FNextBtn);

  FChInfoLbl          := TCastleLabel.Create(FreeAtStop);
  FChInfoLbl.Caption  := 'Loading...';
  FChInfoLbl.Color    := Pal.TextSecondary;
  FChInfoLbl.FontSize := 14;
  FChInfoLbl.Anchor(hpMiddle, hpMiddle);
  FChInfoLbl.Anchor(vpMiddle, vpMiddle);
  FChapterBar.InsertFront(FChInfoLbl);

  { Scroll view }
  FScrollView := TCastleScrollView.Create(FreeAtStop);
  InsertFront(FScrollView);

  { Header: back button (left slot) }
  BackBtn          := TCastleButton.Create(FreeAtStop);
  BackBtn.Caption  := '< Home';
  BackBtn.FontSize := 14;
  BackBtn.OnClick  := @ClickBack;
  FHeader.AddLeft(BackBtn);

  { Blind Edit mode button }
  BlindBtn          := TCastleButton.Create(FreeAtStop);
  BlindBtn.Caption  := 'Blind Edit';
  BlindBtn.FontSize := 13;
  BlindBtn.OnClick  := @ClickBlindEdit;
  FHeader.AddRight(BlindBtn);

  { Source/Translation toggle }
  FToggleBtn          := TCastleButton.Create(FreeAtStop);
  FToggleBtn.Caption  := 'Show Source';
  FToggleBtn.FontSize := 13;
  FToggleBtn.OnClick  := @ClickToggle;
  FHeader.AddRight(FToggleBtn);
end;

procedure TViewEditor.LoadProjectData;
var
  Summary   : TProjectSummary;
  SrcContDir: string;
  SrcDirName, SrcLang, SrcBook, SrcRes: string;
begin
  FProject := nil;
  FSource  := nil;
  FHasSource := False;
  FChapterCount := 0;

  if GAppState.Editor.ProjectDir = '' then Exit;

  FProject := TProject.Create(GAppState.Editor.ProjectDir);

  { Find source content directory }
  Summary := Default(TProjectSummary);
  Summary.BookCode     := TProject(FProject).BookCode;
  Summary.ResourceType := TProject(FProject).ResourceType;
  SrcContDir := FindSourceContentDir(Summary);
  if SrcContDir = '' then
    SrcContDir := FindEnglishULBContentDir(TProject(FProject).BookCode);

  if SrcContDir <> '' then
  begin
    TProject(FProject).LoadContent(SrcContDir);

    { Build TResourceContainer from the parent dir of content/ }
    SrcDirName := ExtractFileName(
      ExcludeTrailingPathDelimiter(
        ExtractFilePath(ExcludeTrailingPathDelimiter(SrcContDir))));
    if TResourceContainer.ParseDirName(SrcDirName, SrcLang, SrcBook, SrcRes) then
    begin
      FSource := TResourceContainer.Create(SrcLang, SrcBook, SrcRes,
        ExcludeTrailingPathDelimiter(
          ExtractFilePath(ExcludeTrailingPathDelimiter(SrcContDir))));
      TResourceContainer(FSource).Load;
      FHasSource := True;
    end;
  end
  else
    LogInfo('Editor: source content directory not found for ' +
      TProject(FProject).BookCode);

  if TProject(FProject).Book <> nil then
    FChapterCount := TProject(FProject).Book.Chapters.Count
  else
    FChapterCount := 0;

  { Clamp chapter index }
  if GAppState.Editor.ChapterIndex >= FChapterCount then
    GAppState.Editor.ChapterIndex := 0;
end;

procedure TViewEditor.LoadChapterContent;
var
  Pal        : TBTTPalette;
  ChIdx      : Integer;
  Chapter    : TChapter;
  SrcChapter : TChapter;
  I          : Integer;
  ChunkText  : string;
  VerseColor : string;
  Lbl        : TCastleLabel;
  Card       : TCastleRectangleControl;
  EditBtn    : TCastleButton;
begin
  FreeAndNil(FChapterContent);
  FChapterContent := TComponent.Create(nil);
  FNeedsRelayout  := True;

  UpdateChapterInfo;

  if (FProject = nil) or (TProject(FProject).Book = nil) then Exit;
  if FChapterCount = 0 then Exit;

  ChIdx := GAppState.Editor.ChapterIndex;
  if (ChIdx < 0) or (ChIdx >= FChapterCount) then Exit;

  Pal        := P;
  VerseColor := '#888888';

  Chapter := TProject(FProject).Book.Chapters[ChIdx];

  { Source chapter reference (for source mode) }
  SrcChapter := nil;
  if FHasSource and (FSource <> nil) then
    if TResourceContainer(FSource).Book <> nil then
      if ChIdx < TResourceContainer(FSource).Book.Chapters.Count then
        SrcChapter := TResourceContainer(FSource).Book.Chapters[ChIdx];

  if FShowSource then
  begin
    { Source mode — single label with all chunks concatenated (read-only) }
    ChunkText := '';
    for I := 0 to Chapter.Chunks.Count - 1 do
    begin
      if (SrcChapter <> nil) and (I < SrcChapter.Chunks.Count) then
      begin
        if ChunkText <> '' then ChunkText := ChunkText + LineEnding + LineEnding;
        ChunkText := ChunkText +
          UsxToRichText(SrcChapter.Chunks[I].Content, VerseColor);
      end;
    end;
    if ChunkText = '' then ChunkText := '<i>(no source)</i>';

    Lbl             := TCastleLabel.Create(FChapterContent);
    Lbl.Caption     := ChunkText;
    Lbl.Html        := True;
    Lbl.Color       := Pal.TextPrimary;
    Lbl.FontSize    := 15;
    Lbl.MaxWidth    := FScrollView.EffectiveWidthForChildren - ContentPad * 2;
    Lbl.Translation := Vector2(ContentPad, ContentPad);
    FScrollView.ScrollArea.InsertFront(Lbl);
  end
  else
  begin
    { Translation mode — one card per chunk with Edit button }
    for I := 0 to Chapter.Chunks.Count - 1 do
    begin
      ChunkText := USFMToRichText(Chapter.Chunks[I].Content, VerseColor);
      if ChunkText = '' then ChunkText := '<i>(empty)</i>';

      { Card owned by FChapterContent; label/button owned by card }
      Card       := TCastleRectangleControl.Create(FChapterContent);
      Card.Color := Pal.PanelBg;
      Card.Tag   := I;
      FScrollView.ScrollArea.InsertFront(Card);

      Lbl          := TCastleLabel.Create(Card);
      Lbl.Caption  := ChunkText;
      Lbl.Html     := True;
      Lbl.Color    := Pal.TextPrimary;
      Lbl.FontSize := 15;
      Lbl.Anchor(hpLeft,  hpLeft,  ChunkCardPad);
      Lbl.Anchor(vpTop,   vpTop,   -ChunkCardPad);
      Card.InsertFront(Lbl);

      EditBtn         := TCastleButton.Create(Card);
      EditBtn.Caption := 'Edit';
      EditBtn.FontSize := 12;
      EditBtn.Tag     := I;
      EditBtn.OnClick := @ClickEditChunk;
      EditBtn.Anchor(hpRight,  hpRight,  -ChunkCardPad);
      EditBtn.Anchor(vpBottom, vpBottom,  ChunkCardPad);
      Card.InsertFront(EditBtn);
    end;

    if Chapter.Chunks.Count = 0 then
    begin
      Lbl             := TCastleLabel.Create(FChapterContent);
      Lbl.Caption     := '(no chunks)';
      Lbl.Html        := False;
      Lbl.Color       := Pal.TextSecondary;
      Lbl.FontSize    := 15;
      Lbl.Translation := Vector2(ContentPad, ContentPad);
      FScrollView.ScrollArea.InsertFront(Lbl);
    end;
  end;
end;

procedure TViewEditor.UpdateChapterInfo;
begin
  if FChInfoLbl = nil then Exit;

  FChInfoLbl.Caption :=
    'Chapter ' + IntToStr(GAppState.Editor.ChapterIndex + 1) +
    ' of '     + IntToStr(FChapterCount);

  FPrevBtn.Exists := (GAppState.Editor.ChapterIndex > 0);
  FNextBtn.Exists := (GAppState.Editor.ChapterIndex < FChapterCount - 1);

  if FToggleBtn <> nil then
    FToggleBtn.Caption :=
      BoolToStr(FShowSource, 'Show Translation', 'Show Source');
end;

procedure TViewEditor.UpdateScrollHeight;
var
  AreaW      : Single;
  TotalH     : Single;
  CurBottom  : Single;
  I          : Integer;
  Ctrl       : TCastleUserInterface;
  Card       : TCastleRectangleControl;
  Lbl        : TCastleLabel;
  LblH, CardH: Single;
  J          : Integer;
begin
  if FScrollView = nil then Exit;
  AreaW := FScrollView.EffectiveWidthForChildren;
  if AreaW < 1 then Exit;

  if FShowSource then
  begin
    { Single-label source mode — same as before }
    Lbl := nil;
    for I := 0 to FScrollView.ScrollArea.ControlsCount - 1 do
      if FScrollView.ScrollArea.Controls[I] is TCastleLabel then
      begin
        Lbl := TCastleLabel(FScrollView.ScrollArea.Controls[I]);
        Break;
      end;
    if Lbl = nil then Exit;
    Lbl.MaxWidth := AreaW - ContentPad * 2;
    FScrollView.ScrollArea.Width  := AreaW;
    FScrollView.ScrollArea.Height :=
      Max(FScrollView.Height, Lbl.EffectiveHeight + ContentPad * 2);
  end
  else
  begin
    { Card mode — calculate each card height from its label, then position }
    TotalH := ChunkCardGap;
    for I := 0 to FScrollView.ScrollArea.ControlsCount - 1 do
    begin
      Ctrl := FScrollView.ScrollArea.Controls[I];
      if not (Ctrl is TCastleRectangleControl) then Continue;
      Card := TCastleRectangleControl(Ctrl);

      { Find the label child of this card }
      Lbl := nil;
      for J := 0 to Card.ControlsCount - 1 do
        if Card.Controls[J] is TCastleLabel then
        begin
          Lbl := TCastleLabel(Card.Controls[J]);
          Break;
        end;

      if Lbl <> nil then
      begin
        Lbl.MaxWidth := AreaW - ChunkCardPad * 2;
        LblH := Lbl.EffectiveHeight;
      end
      else
        LblH := 0;

      CardH := LblH + ChunkCardPad * 2 + EditBtnH + 8;
      TotalH := TotalH + CardH + ChunkCardGap;
    end;

    { Position cards from top down (CGE: y=0 at bottom) }
    FScrollView.ScrollArea.Width  := AreaW;
    FScrollView.ScrollArea.Height := Max(FScrollView.Height, TotalH);

    CurBottom := Max(FScrollView.Height, TotalH) - ChunkCardGap;
    for I := 0 to FScrollView.ScrollArea.ControlsCount - 1 do
    begin
      Ctrl := FScrollView.ScrollArea.Controls[I];
      if not (Ctrl is TCastleRectangleControl) then Continue;
      Card := TCastleRectangleControl(Ctrl);

      Lbl := nil;
      for J := 0 to Card.ControlsCount - 1 do
        if Card.Controls[J] is TCastleLabel then
        begin
          Lbl := TCastleLabel(Card.Controls[J]);
          Break;
        end;

      if Lbl <> nil then LblH := Lbl.EffectiveHeight else LblH := 0;
      CardH := LblH + ChunkCardPad * 2 + EditBtnH + 8;
      CurBottom := CurBottom - CardH;

      Card.Translation := Vector2(0, CurBottom);
      Card.Width       := AreaW;
      Card.Height      := CardH;

      CurBottom := CurBottom - ChunkCardGap;
    end;
  end;
end;

procedure TViewEditor.ClickBack(Sender: TObject);
begin
  GAppState.Screen := asHome;
  ResetEditorState;
  Container.View := ViewHome;
end;

procedure TViewEditor.ClickBlindEdit(Sender: TObject);
begin
  GAppState.Editor.ChunkIndex := 0;
  Container.View := ViewBlindEdit;
end;

procedure TViewEditor.ClickToggle(Sender: TObject);
begin
  FShowSource := not FShowSource;
  LoadChapterContent;
end;

procedure TViewEditor.ClickPrev(Sender: TObject);
begin
  if GAppState.Editor.ChapterIndex > 0 then
  begin
    Dec(GAppState.Editor.ChapterIndex);
    LoadChapterContent;
  end;
end;

procedure TViewEditor.ClickNext(Sender: TObject);
begin
  if GAppState.Editor.ChapterIndex < FChapterCount - 1 then
  begin
    Inc(GAppState.Editor.ChapterIndex);
    LoadChapterContent;
  end;
end;

procedure TViewEditor.ClickEditChunk(Sender: TObject);
var
  ChIdx   : Integer;
  Chapter : TChapter;
  Idx     : Integer;
begin
  Idx := (Sender as TCastleButton).Tag;
  if (FProject = nil) or (TProject(FProject).Book = nil) then Exit;

  ChIdx := GAppState.Editor.ChapterIndex;
  if (ChIdx < 0) or (ChIdx >= FChapterCount) then Exit;

  Chapter := TProject(FProject).Book.Chapters[ChIdx];
  if (Idx < 0) or (Idx >= Chapter.Chunks.Count) then Exit;

  FEditingChunkIdx := Idx;
  ViewChunkEdit.InputText := Chapter.Chunks[Idx].Content;
  FChunkEdit := ViewChunkEdit;
  Container.PushView(ViewChunkEdit);
end;

procedure TViewEditor.Resize;
var
  W, H: Single;
begin
  inherited;
  if FHeader = nil then Exit;
  W := EffectiveWidth;
  H := EffectiveHeight;

  FHeader.Translation := Vector2(0, H - BTT_HEADER_H);
  FHeader.Width       := W;
  FHeader.Height      := BTT_HEADER_H;

  FChapterBar.Translation := Vector2(0, H - BTT_HEADER_H - ChapterBarH);
  FChapterBar.Width       := W;
  FChapterBar.Height      := ChapterBarH;

  FScrollView.Translation := Vector2(0, 0);
  FScrollView.Width       := W;
  FScrollView.Height      := H - BTT_HEADER_H - ChapterBarH;

  FNeedsRelayout := True;
end;

procedure TViewEditor.Update(const SecondsPassed: Single;
  var HandleInput: Boolean);
begin
  inherited;
  if FNeedsRelayout then
  begin
    FNeedsRelayout := False;
    UpdateScrollHeight;
  end;
end;

procedure TViewEditor.OnThemeChange;
begin
  if Container <> nil then
    Container.View := Self;
end;

end.
