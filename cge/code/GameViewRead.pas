{$mode objfpc}{$H+}
unit GameViewRead;

{ Read mode — full-chapter read-only view.

  Shows the complete chapter as continuous flowing text in a single
  scrollable label.  A toggle switches between source and translation.

  Layout:
    BTTHeader (60 px)   — Back, "Read Mode", Source/Trans toggle
    ChapterBar (44 px)  — Prev / Next chapter navigation
    ScrollView          — single TCastleLabel with rich text for the chapter

  Source text uses UsxToRichText; translation uses USFMToRichText on the
  merged chapter content.
}

interface

uses
  Classes,
  CastleUIControls, CastleControls, CastleColors,
  CGEViewBase, BTTHeader;

type
  TViewRead = class(TCGEViewBase)
  private
    { ── chrome ── }
    FHeader      : TBTTHeader;
    FToggleBtn   : TCastleButton;
    FChapterBar  : TCastleRectangleControl;
    FChInfoLbl   : TCastleLabel;
    FPrevBtn     : TCastleButton;
    FNextBtn     : TCastleButton;
    FScrollView  : TCastleScrollView;

    { ── content ── }
    FTextLbl     : TCastleLabel;
    FNeedsLayout : Boolean;

    { ── data ── }
    FProject     : TObject;   { TProject }
    FSource      : TObject;   { TResourceContainer }
    FHasSource   : Boolean;
    FChapterCount: Integer;
    FShowSource  : Boolean;   { True = show source text, False = translation }

    procedure BuildChrome;
    procedure LoadProjectData;
    procedure LoadChapterText;
    procedure UpdateChapterInfo;
    procedure UpdateScrollHeight;

    procedure ClickBack(Sender: TObject);
    procedure ClickToggle(Sender: TObject);
    procedure ClickPrev(Sender: TObject);
    procedure ClickNext(Sender: TObject);
  public
    procedure Start;  override;
    procedure Stop;   override;
    procedure Resize; override;
    procedure Update(const SecondsPassed: Single; var HandleInput: Boolean); override;
    procedure OnThemeChange; override;
  end;

var
  ViewRead: TViewRead;

implementation

uses
  SysUtils, Math, CastleVectors,
  AppState, BTTTheme, AppLog,
  DataPaths, ProjectManager, ResourceContainer, ProjectScanner,
  BibleBook, BibleChapter,
  USFMRenderer,
  GameViewEditor;

const
  ChapterBarH = 44;
  TextPad     = 20;

{ Convert a TCastleColor to a CSS hex string (e.g. '#00A56C') for rich text. }
function PaletteColorToHex(const C: TCastleColor): string;
begin
  Result := Format('#%2.2X%2.2X%2.2X',
    [Round(Min(Max(C.X, 0.0), 1.0) * 255.0),
     Round(Min(Max(C.Y, 0.0), 1.0) * 255.0),
     Round(Min(Max(C.Z, 0.0), 1.0) * 255.0)]);
end;

{ ── helpers ── }

function ProjectRef(V: TViewRead): TProject; inline;
begin
  Result := TProject(V.FProject);
end;

function SourceRef(V: TViewRead): TResourceContainer; inline;
begin
  Result := TResourceContainer(V.FSource);
end;

{ ── lifecycle ── }

procedure TViewRead.Start;
begin
  inherited;
  ApplyBackground;
  FShowSource   := False;
  FNeedsLayout  := False;
  BuildChrome;
  LoadProjectData;
  LoadChapterText;
end;

procedure TViewRead.Stop;
begin
  if FProject <> nil then TProject(FProject).Free;
  FProject := nil;
  if FSource <> nil then TResourceContainer(FSource).Free;
  FSource := nil;
  inherited;
end;

{ ── chrome ── }

procedure TViewRead.BuildChrome;
var
  Pal     : TBTTPalette;
  BackBtn : TCastleButton;
begin
  Pal := P;

  FHeader := TBTTHeader.Create(FreeAtStop, Pal);
  FHeader.SetTitle(GAppState.Editor.ProjectTitle + ' — Read');
  InsertFront(FHeader);

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
  FChInfoLbl.Caption  := '';
  FChInfoLbl.Color    := Pal.TextSecondary;
  FChInfoLbl.FontSize := 14;
  FChInfoLbl.Anchor(hpMiddle, hpMiddle);
  FChInfoLbl.Anchor(vpMiddle, vpMiddle);
  FChapterBar.InsertFront(FChInfoLbl);

  FScrollView := TCastleScrollView.Create(FreeAtStop);
  InsertFront(FScrollView);

  { Text label inside scroll area }
  FTextLbl          := TCastleLabel.Create(FreeAtStop);
  FTextLbl.Caption  := '';
  FTextLbl.Color    := P.TextPrimary;
  FTextLbl.FontSize := 15;
  FTextLbl.Html     := True;
  FTextLbl.Translation := CastleVectors.Vector2(TextPad, 0);
  FScrollView.ScrollArea.InsertFront(FTextLbl);

  { Header buttons }
  BackBtn          := TCastleButton.Create(FreeAtStop);
  BackBtn.Caption  := '< Edit';
  BackBtn.FontSize := 14;
  BackBtn.OnClick  := @ClickBack;
  FHeader.AddLeft(BackBtn);

  FToggleBtn          := TCastleButton.Create(FreeAtStop);
  FToggleBtn.Caption  := 'Show Source';
  FToggleBtn.FontSize := 13;
  FToggleBtn.OnClick  := @ClickToggle;
  FHeader.AddRight(FToggleBtn);
end;

{ ── data loading ── }

procedure TViewRead.LoadProjectData;
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

  Summary := Default(TProjectSummary);
  Summary.BookCode     := TProject(FProject).BookCode;
  Summary.ResourceType := TProject(FProject).ResourceType;
  SrcContDir := FindSourceContentDir(Summary);
  if SrcContDir = '' then
    SrcContDir := FindEnglishULBContentDir(TProject(FProject).BookCode);

  if SrcContDir <> '' then
  begin
    TProject(FProject).LoadContent(SrcContDir);

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
  end;

  if TProject(FProject).Book <> nil then
    FChapterCount := TProject(FProject).Book.Chapters.Count
  else
    FChapterCount := 0;

  { Disable toggle when no source is loaded }
  FToggleBtn.Enabled := FHasSource;
  if not FHasSource then
    FShowSource := False;
end;

{ ── chapter rendering ── }

procedure TViewRead.LoadChapterText;
var
  Pal        : TBTTPalette;
  ChIdx      : Integer;
  Rich       : string;
  I          : Integer;
  SrcChapter : TChapter;
  ProjChapter: TChapter;
  MergedText : string;
begin
  Pal := P;
  ChIdx := GAppState.Editor.ChapterIndex;
  Rich  := '';

  UpdateChapterInfo;

  if FShowSource then
  begin
    { Concatenate all source chunks for the chapter }
    if FHasSource and (SourceRef(Self) <> nil) and
       (SourceRef(Self).Book <> nil) and
       (ChIdx >= 0) and (ChIdx < SourceRef(Self).Book.Chapters.Count) then
    begin
      SrcChapter := SourceRef(Self).Book.Chapters[ChIdx];
      for I := 0 to SrcChapter.Chunks.Count - 1 do
        Rich := Rich + UsxToRichText(SrcChapter.Chunks[I].Content,
          PaletteColorToHex(Pal.Accent));
    end
    else
      Rich := '<i>Source text not available.</i>';
    FTextLbl.Color := Pal.TextPrimary;
    FToggleBtn.Caption := 'Show Translation';
  end
  else
  begin
    { Merge all project chunks for the chapter }
    ProjChapter := nil;
    if (FProject <> nil) and (ProjectRef(Self).Book <> nil) then
    begin
      if (ChIdx >= 0) and (ChIdx < ProjectRef(Self).Book.Chapters.Count) then
      begin
        ProjChapter := ProjectRef(Self).Book.Chapters[ChIdx];
      end;
    end;

    if ProjChapter <> nil then
    begin
      MergedText := ProjChapter.MergeAllContent;
      if Trim(MergedText) = '' then
        Rich := '<i>No translation yet for this chapter.</i>'
      else
        Rich := USFMToRichText(MergedText, PaletteColorToHex(Pal.Accent));
    end
    else
      Rich := '<i>No translation yet.</i>';
    FTextLbl.Color := Pal.TextPrimary;
    FToggleBtn.Caption := 'Show Source';
  end;

  FTextLbl.Caption := Rich;
  FNeedsLayout := True;
end;

procedure TViewRead.UpdateChapterInfo;
var
  ChIdx, Total : Integer;
  ChID         : string;
begin
  ChIdx := GAppState.Editor.ChapterIndex;
  Total := FChapterCount;
  if Total = 0 then
  begin
    FChInfoLbl.Caption := 'No chapters';
    FPrevBtn.Enabled   := False;
    FNextBtn.Enabled   := False;
    Exit;
  end;

  ChID := '';
  if (FProject <> nil) and (ProjectRef(Self).Book <> nil) and
     (ChIdx >= 0) and (ChIdx < Total) then
    ChID := ProjectRef(Self).Book.Chapters[ChIdx].ID;
  if ChID = '' then ChID := IntToStr(ChIdx + 1);

  FChInfoLbl.Caption := 'Chapter ' + ChID + ' of ' + IntToStr(Total);
  FPrevBtn.Enabled   := ChIdx > 0;
  FNextBtn.Enabled   := ChIdx < Total - 1;
end;

procedure TViewRead.UpdateScrollHeight;
var
  AreaW, TxtH: Single;
begin
  if FScrollView = nil then Exit;
  AreaW := FScrollView.EffectiveWidthForChildren;
  if AreaW < 1 then Exit;

  FTextLbl.MaxWidth := AreaW - TextPad * 2;
  TxtH := FTextLbl.EffectiveHeight;

  FScrollView.ScrollArea.Width  := AreaW;
  FScrollView.ScrollArea.Height := Max(FScrollView.Height, TxtH + TextPad * 2);
  { Pin label to top of scroll area (CGE: y=0 at bottom) }
  FTextLbl.Translation := CastleVectors.Vector2(
    TextPad,
    FScrollView.ScrollArea.Height - TextPad - TxtH);
end;

{ ── navigation ── }

procedure TViewRead.ClickBack(Sender: TObject);
begin
  Container.View := ViewEditor;
end;

procedure TViewRead.ClickToggle(Sender: TObject);
begin
  FShowSource := not FShowSource;
  LoadChapterText;
end;

procedure TViewRead.ClickPrev(Sender: TObject);
begin
  if GAppState.Editor.ChapterIndex > 0 then
  begin
    Dec(GAppState.Editor.ChapterIndex);
    FScrollView.Scroll := 0;
    LoadChapterText;
  end;
end;

procedure TViewRead.ClickNext(Sender: TObject);
begin
  if GAppState.Editor.ChapterIndex < FChapterCount - 1 then
  begin
    Inc(GAppState.Editor.ChapterIndex);
    FScrollView.Scroll := 0;
    LoadChapterText;
  end;
end;

{ ── layout ── }

procedure TViewRead.Resize;
var
  W, H : Single;
begin
  inherited;
  if FHeader = nil then Exit;
  W := EffectiveWidth;
  H := EffectiveHeight;

  FHeader.Translation := CastleVectors.Vector2(0, H - BTT_HEADER_H);
  FHeader.Width       := W;
  FHeader.Height      := BTT_HEADER_H;

  FChapterBar.Translation := CastleVectors.Vector2(0, H - BTT_HEADER_H - ChapterBarH);
  FChapterBar.Width       := W;
  FChapterBar.Height      := ChapterBarH;

  FScrollView.Translation := CastleVectors.Vector2(0, 0);
  FScrollView.Width       := W;
  FScrollView.Height      := H - BTT_HEADER_H - ChapterBarH;

  FNeedsLayout := True;
end;

procedure TViewRead.Update(const SecondsPassed: Single; var HandleInput: Boolean);
begin
  inherited;
  if FNeedsLayout then
  begin
    FNeedsLayout := False;
    UpdateScrollHeight;
  end;
end;

procedure TViewRead.OnThemeChange;
begin
  if Container <> nil then
    Container.View := Self;
end;

end.
