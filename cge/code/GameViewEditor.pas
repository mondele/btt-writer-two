{$mode objfpc}{$H+}
unit GameViewEditor;

{ Read-mode editor view — Phase 4.
  Displays a chapter's source or translation text as rich CGE labels.
  Navigation: prev/next chapter buttons below the header.
  Toggle: source ↔ translation via a header-right button.
  Chapter content is rebuilt via LoadChapterContent without a full view
  restart; only project data is loaded once in Start.

  Layout (top-to-bottom):
    BTTHeader  (60 px)   — Back button, project+chapter title, mode toggle
    ChapterBar (44 px)   — Prev / Next chapter navigation
    ScrollView (rest)    — content labels
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
    FChapterContent : TComponent;  { owns the current chapter's labels }
    FNeedsRelayout  : Boolean;

    procedure BuildChrome;
    procedure LoadProjectData;
    procedure LoadChapterContent;
    procedure UpdateChapterInfo;
    procedure UpdateScrollHeight;

    procedure ClickBack(Sender: TObject);
    procedure ClickToggle(Sender: TObject);
    procedure ClickPrev(Sender: TObject);
    procedure ClickNext(Sender: TObject);
  public
    procedure Start; override;
    procedure Stop; override;
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
  GameViewHome;

const
  ChapterBarH = 44;
  ContentPad  = 16;

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
  FShowSource := False;
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
  inherited;
end;

procedure TViewEditor.Resume;
begin
  inherited;
  { Returning from a pushed modal (e.g. future settings dialog) — nothing needed. }
end;

procedure TViewEditor.BuildChrome;
var
  Pal     : TBTTPalette;
  BackBtn : TCastleButton;
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
  FullText   : string;
  I          : Integer;
  ChunkTrans , ChunkSrc: string;
  Lbl        : TCastleLabel;
  VerseColor : string;
begin
  FreeAndNil(FChapterContent);
  FChapterContent := TComponent.Create(nil);
  FNeedsRelayout  := True;

  UpdateChapterInfo;

  if (FProject = nil) or (TProject(FProject).Book = nil) then Exit;
  if FChapterCount = 0 then Exit;

  ChIdx := GAppState.Editor.ChapterIndex;
  if (ChIdx < 0) or (ChIdx >= FChapterCount) then Exit;

  Pal := P;
  VerseColor := '#888888';

  Chapter := TProject(FProject).Book.Chapters[ChIdx];

  { Build source chapter reference }
  SrcChapter := nil;
  if FHasSource and (FSource <> nil) then
  begin
    if TResourceContainer(FSource).Book <> nil then
      if ChIdx < TResourceContainer(FSource).Book.Chapters.Count then
        SrcChapter := TResourceContainer(FSource).Book.Chapters[ChIdx];
  end;

  { Assemble full chapter text from chunks }
  FullText := '';
  for I := 0 to Chapter.Chunks.Count - 1 do
  begin
    if FShowSource then
    begin
      { Source mode }
      if (SrcChapter <> nil) and (I < SrcChapter.Chunks.Count) then
        ChunkSrc := UsxToRichText(SrcChapter.Chunks[I].Content, VerseColor)
      else
        ChunkSrc := '';
      if FullText <> '' then FullText := FullText + LineEnding + LineEnding;
      FullText := FullText + ChunkSrc;
    end
    else
    begin
      { Translation mode }
      ChunkTrans := USFMToRichText(Chapter.Chunks[I].Content, VerseColor);
      if FullText <> '' then FullText := FullText + LineEnding + LineEnding;
      FullText := FullText + ChunkTrans;
    end;
  end;

  if FullText = '' then
    FullText := '<i>(no content)</i>';

  { Create the content label, owned by FChapterContent so it can be replaced }
  Lbl             := TCastleLabel.Create(FChapterContent);
  Lbl.Caption     := FullText;
  Lbl.Html        := True;
  Lbl.Color       := Pal.TextPrimary;
  Lbl.FontSize    := 15;
  Lbl.MaxWidth    := FScrollView.EffectiveWidthForChildren - ContentPad * 2;
  Lbl.Translation := Vector2(ContentPad, ContentPad);
  FScrollView.ScrollArea.InsertFront(Lbl);
end;

procedure TViewEditor.UpdateChapterInfo;
var
  BookName: string;
  ChIdx: Integer;
begin
  if FChInfoLbl = nil then Exit;

  BookName := GAppState.Editor.BookCode;
  if TProject(FProject) <> nil then ; { already using BookCode from AppState }

  ChIdx := GAppState.Editor.ChapterIndex;
  FChInfoLbl.Caption :=
    'Chapter ' + IntToStr(ChIdx + 1) +
    ' of ' + IntToStr(FChapterCount);

  FPrevBtn.Exists := (ChIdx > 0);
  FNextBtn.Exists := (ChIdx < FChapterCount - 1);

  if FToggleBtn <> nil then
    FToggleBtn.Caption :=
      BoolToStr(FShowSource, 'Show Translation', 'Show Source');
end;

procedure TViewEditor.UpdateScrollHeight;
var
  Lbl: TCastleLabel;
  AreaW: Single;
  I: Integer;
begin
  { Find the content label in the scroll area }
  Lbl := nil;
  for I := 0 to FScrollView.ScrollArea.ControlsCount - 1 do
    if FScrollView.ScrollArea.Controls[I] is TCastleLabel then
    begin
      Lbl := TCastleLabel(FScrollView.ScrollArea.Controls[I]);
      Break;
    end;

  if Lbl = nil then Exit;

  AreaW := FScrollView.EffectiveWidthForChildren - ContentPad * 2;
  if AreaW < 1 then Exit;

  Lbl.MaxWidth := AreaW;
  FScrollView.ScrollArea.Width  := FScrollView.EffectiveWidthForChildren;
  FScrollView.ScrollArea.Height :=
    Max(FScrollView.Height, Lbl.EffectiveHeight + ContentPad * 2);
end;

procedure TViewEditor.ClickBack(Sender: TObject);
begin
  GAppState.Screen := asHome;
  ResetEditorState;
  Container.View := ViewHome;
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
