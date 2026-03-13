unit ProjectEditForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs,
  ExtCtrls, StdCtrls, Buttons, ComCtrls, LCLIntf, LCLType,
  fpjson, jsonparser,
  ProjectManager, ResourceContainer, ProjectScanner,
  BibleBook, BibleChapter, BibleChunk, USFMUtils, DataPaths, ProjectCreator,
  AppSettings, SettingsForm, ThemePalette, UIFonts, AppLog,
  IndexDatabase, SourceExtractor;

resourcestring
  rsErrorOpeningChapterPrefix = 'Error opening chapter: ';
  rsReturningHomeScreen = 'Returning to home screen.';
  rsAutoSavedAtPrefix = 'Auto-saved at ';
  rsAutoSaveFailedPrefix = 'Auto-save failed: ';
  rsCannotPrepareSourceTextPrefix = 'Cannot prepare source text for ';
  rsCannotPrepareSourceTextMid = ': ';
  rsCannotFindSourceTextContentPrefix = 'Cannot find source text content for ';
  rsCannotFindSourceTextContentSuffix = '.';
  rsSourceTextHeader = 'Source Text';
  rsTranslationHeaderPrefix = 'Translation (';
  rsUnableToOpenProjectPrefix = 'Unable to open project "';
  rsUnableToOpenProjectMid = '" due to invalid or oversized chunk content: ';
  rsChunkTitle = 'Title';
  rsChunkVersePrefix = 'v';
  rsChunkVerseRangeJoin = '-';
  rsErrorRenderingChapterPrefix = 'Error rendering chapter content: ';
  rsUpdateChapterPrefix = 'Update chapter ';
  rsStatusChapterFmt = 'Chapter %s of %d | %d/%d chunks finished';
  rsSavedAtPrefix = 'Saved at ';
  rsFinishedToggleLabel = 'Mark chunk as done';
  rsLoadingProject = 'Loading project...';
  rsLoadingSourceText = 'Loading source text...';
  rsLoadingTranslation = 'Loading translation...';
  rsLoadingChapter = 'Loading chapter...';

type
  TResourceTab = (rtNotes, rtWords, rtQuestions);

  TSegmentKind = (
    skText,       { plain text }
    skVerse,      { \v N — verse number badge }
    skFootnote,   { \f ... \f* — footnote indicator }
    skHeading,    { \s — section heading (bold, larger) }
    skDescription { \d — descriptive title (italic) }
  );

  TTextSegment = record
    Kind: TSegmentKind;
    Text: string;
  end;
  TTextSegmentArray = array of TTextSegment;

  { Custom control that renders USFM text with verse numbers as colored badges }
  TVerseDisplay = class(TCustomControl)
  private
    FText: string;
    FRawText: string;  { original text with \v markers, for save }
    FBadgeColor: TColor;
    FSegments: TTextSegmentArray;
    procedure SetText(const AText: string);
    procedure ParseSegments;
    procedure AddSegment(AKind: TSegmentKind; const AText: string);
    function MatchMarker(const S: string; P: Integer; const Marker: string): Boolean;
    function DoLayout(ACanvas: TCanvas; AWidth: Integer; ADraw: Boolean): Integer;
    procedure DrawWordWrapped(ACanvas: TCanvas; const AText: string;
      var X, Y: Integer; MaxW, LineH, SpaceW: Integer; ADraw: Boolean);
  protected
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    function CalcNeededHeight(AWidth: Integer): Integer;
    property Text: string read FRawText write SetText;
    property BadgeColor: TColor read FBadgeColor write FBadgeColor;
  end;

  TChunkPanel = class;

  { TProjectEditWindow }

  TProjectEditWindow = class(TForm)
    btnMenu: TSpeedButton;
    LeftRail: TPanel;
    TopPanel: TPanel;
    btnBack: TButton;
    lblProjectTitle: TLabel;
    lblChapterNav: TLabel;
    btnPrevChapter: TButton;
    lblChapterNum: TLabel;
    btnNextChapter: TButton;
    StatusPanel: TPanel;
    lblStatus: TLabel;
    SplitPanel: TPanel;
    PaneHeaderBar: TPanel;
    lblSourceHeader: TLabel;
    SourceLangHeader: TLabel;
    btnChangeSource: TButton;
    lblTransHeader: TLabel;
    lblTransLangHeader: TLabel;
    btnTabNotes: TButton;
    btnTabWords: TButton;
    btnTabQuestions: TButton;
    Splitter1: TSplitter;
    Splitter2: TSplitter;
    SourcePanel: TPanel;
    SourceScrollBox: TScrollBox;
    TransPanel: TPanel;
    TransScrollBox: TScrollBox;
    ResourcePanel: TPanel;
    ResourceMemo: TMemo;
    AutoSaveTimer: TTimer;
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormResize(Sender: TObject);
    procedure btnMenuClick(Sender: TObject);
    procedure btnBackClick(Sender: TObject);
    procedure btnPrevChapterClick(Sender: TObject);
    procedure btnNextChapterClick(Sender: TObject);
    procedure AutoSaveTimerFire(Sender: TObject);
  private
    FProject: TProject;
    FSourceRC: TResourceContainer;
    FCurrentChapterIndex: Integer;
    FChunkPanels: array of TChunkPanel;
    FProjectPath: string;
    FSourceContentDir: string;
    FEnglishULBContentDir: string;
    FScrollSyncTimer: TTimer;
    FLastSourcePos: Integer;
    FLastTransPos: Integer;
    FSyncingScroll: Boolean;
    FSelectedChunkIndex: Integer;
    FActiveResourceTab: TResourceTab;
    FLayoutDirection: string;
    FSourceLangCode: string;
    FSourceResourceType: string;
    FBookCode: string;
    FSummary: TProjectSummary;

    procedure ClearChunkPanels;
    procedure LoadChapter(AIndex: Integer);
    procedure SaveCurrentChapter;
    procedure UpdateStatus;
    procedure UpdateChapterNav;
    procedure OnChunkFinishedChange(Sender: TObject);
    procedure OnChunkFinishedToggleClick(Sender: TObject);
    procedure OnChunkMemoExit(Sender: TObject);
    procedure OnChunkEditClick(Sender: TObject);
    procedure OnChunkPanelClick(Sender: TObject);
    procedure OnResourceTabClick(Sender: TObject);
    procedure PaneMouseWheel(Sender: TObject; Shift: TShiftState;
      WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
    procedure ScrollSyncTimerFire(Sender: TObject);
    procedure AttachWheelHandlers(AParent: TWinControl);
    function IsControlInPane(AControl: TControl; APane: TWinControl): Boolean;
    procedure SetSelectedChunkIndex(AIndex: Integer);
    procedure UpdateResourcePanelForSelectedChunk;
    function ResourceDirFor(const ResourceID: string): string;
    procedure CollectChunkResources(const ChapterID: string; ChunkStart, ChunkEnd: Integer;
      const ResourceDir: string; OutList: TStringList);
    procedure CollectWordsResources(const ChapterID: string; ChunkStart, ChunkEnd: Integer;
      OutList: TStringList);
    procedure ApplyOrientationLayout(const Direction: string);
    procedure UpdatePaneHeaders;
    procedure ApplyTheme;
    procedure btnChangeSourceClick(Sender: TObject);
    procedure SplitterMoved(Sender: TObject);
    procedure RecalcAllChunkLayouts;
    procedure ScheduleRecalcLayout;
    procedure RecalcLayoutTimerFire(Sender: TObject);
  private
    FRecalcTimer: TTimer;
  private
    { Loading splash }
    FLoadingSplash: TForm;
    FLoadingLabel: TLabel;
    FLoadingBar: TProgressBar;
    procedure ShowLoadingSplash(const AText: string);
    procedure UpdateLoadingSplash(const AText: string; AProgress: Integer);
    procedure HideLoadingSplash;
  public
    procedure OpenProject(const APath: string; const ASummary: TProjectSummary);
  end;

  TChunkPanel = class
  private
    FSourcePanel: TPanel;
    FTransPanel: TPanel;
    FSourceDisplay: TVerseDisplay;
    FTransDisplay: TVerseDisplay;
    FTransText: string;  { raw USFM text for this chunk }
    FTransMemo: TMemo;
    FEditButton: TButton;
    FFinishedCheck: TCheckBox;
    FFinishedTrack: TShape;
    FFinishedKnob: TShape;
    FFinishedToggleBtn: TSpeedButton;
    FFinishedLabel: TLabel;
    FChapterID: string;
    FChunkName: string;
    FStartVerse: Integer;
    FEndVerse: Integer;
    FProject: TProject;
    FEditing: Boolean;
    FOwnerForm: TProjectEditWindow;
  public
    constructor Create(AOwnerForm: TProjectEditWindow;
      ASourceParent, ATransParent: TScrollBox;
      const ASourceText, ATransText, AChapterID, AChunkName, AVerseLabel: string;
      AStartVerse, AEndVerse: Integer;
      AFinished: Boolean; AProject: TProject);
    destructor Destroy; override;
    procedure SetEditing(AEdit: Boolean);
    procedure SaveContent;
    procedure RecalcLayout;
    procedure UpdateFinishedVisuals;
    procedure SetSelected(ASelected: Boolean);
    function OwnsControl(AObj: TObject): Boolean;
    function GetHeight: Integer;
    property StartVerse: Integer read FStartVerse;
    property EndVerse: Integer read FEndVerse;
    property SourcePanel: TPanel read FSourcePanel;
    property TransPanel: TPanel read FTransPanel;
  end;

var
  ProjectEditWindow: TProjectEditWindow;

implementation

{$R *.lfm}

{ Delete all files with the given extension from a directory }
procedure CleanChapterDir(const Dir, Ext: string);
var
  SR: TSearchRec;
  FullDir: string;
begin
  FullDir := IncludeTrailingPathDelimiter(Dir);
  if FindFirst(FullDir + '*' + Ext, faAnyFile, SR) = 0 then
  begin
    repeat
      if (SR.Attr and faDirectory) = 0 then
        DeleteFile(FullDir + SR.Name);
    until FindNext(SR) <> 0;
    FindClose(SR);
  end;
end;

{ ---- TVerseDisplay ---- }

constructor TVerseDisplay.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FBadgeColor := $D9904A;  { blue-ish }
  FText := '';
  FRawText := '';
  Font.Name := 'Roboto';
  Color := clWhite;
end;

procedure TVerseDisplay.SetText(const AText: string);
begin
  FRawText := AText;
  FText := AText;
  ParseSegments;
  Invalidate;
end;

procedure TVerseDisplay.AddSegment(AKind: TSegmentKind; const AText: string);
begin
  SetLength(FSegments, Length(FSegments) + 1);
  FSegments[High(FSegments)].Kind := AKind;
  FSegments[High(FSegments)].Text := AText;
end;

function TVerseDisplay.MatchMarker(const S: string; P: Integer;
  const Marker: string): Boolean;
{ Check if S at position P starts with backslash + Marker + space/newline/end }
var
  MLen: Integer;
begin
  Result := False;
  MLen := Length(Marker);
  if P + MLen > Length(S) then
    Exit;
  if S[P] <> '\' then
    Exit;
  if Copy(S, P + 1, MLen) <> Marker then
    Exit;
  { Must be followed by space, newline, or end of string }
  if P + MLen + 1 > Length(S) then
    Result := True
  else
    Result := S[P + MLen + 1] in [' ', #10, #13];
end;

procedure TVerseDisplay.ParseSegments;
var
  S: string;
  P, Start, EndP: Integer;
  SegText: string;
begin
  SetLength(FSegments, 0);
  S := FText;
  if S = '' then
    Exit;

  P := 1;
  while P <= Length(S) do
  begin
    if S[P] <> '\' then
    begin
      { Collect plain text until next backslash or end }
      Start := P;
      while (P <= Length(S)) and (S[P] <> '\') do
        Inc(P);
      SegText := Copy(S, Start, P - Start);
      if Trim(SegText) <> '' then
        AddSegment(skText, SegText);
    end
    else if MatchMarker(S, P, 'v') then
    begin
      { \v N — verse marker }
      P := P + 3; { skip \v and space }
      Start := P;
      while (P <= Length(S)) and (S[P] in ['0'..'9', '-']) do
        Inc(P);
      AddSegment(skVerse, Copy(S, Start, P - Start));
      { Skip trailing whitespace/newline so verse text can stay on same line. }
      while (P <= Length(S)) and (S[P] in [' ', #9, #10, #13]) do
        Inc(P);
    end
    else if MatchMarker(S, P, 'f') then
    begin
      { \f ... \f* — footnote: skip to closing marker, emit indicator }
      Start := P;
      EndP := Pos('\f*', S, P);
      if EndP > 0 then
        P := EndP + 3
      else
        P := Length(S) + 1;
      AddSegment(skFootnote, '');
    end
    else if MatchMarker(S, P, 'd') then
    begin
      { \d Text — descriptive title, runs to end of line }
      P := P + 2; { skip \d }
      if (P <= Length(S)) and (S[P] = ' ') then
        Inc(P);
      Start := P;
      while (P <= Length(S)) and not (S[P] in [#10, #13]) do
        Inc(P);
      SegText := Trim(Copy(S, Start, P - Start));
      if SegText <> '' then
        AddSegment(skDescription, SegText);
      { Skip newline }
      if (P <= Length(S)) and (S[P] = #13) then Inc(P);
      if (P <= Length(S)) and (S[P] = #10) then Inc(P);
    end
    else if MatchMarker(S, P, 's') then
    begin
      { \s or \s1...\s5 — section heading, runs to end of line }
      P := P + 2; { skip \s }
      { Skip optional digit }
      if (P <= Length(S)) and (S[P] in ['1'..'5']) then
        Inc(P);
      if (P <= Length(S)) and (S[P] = ' ') then
        Inc(P);
      Start := P;
      while (P <= Length(S)) and not (S[P] in [#10, #13]) do
        Inc(P);
      SegText := Trim(Copy(S, Start, P - Start));
      if SegText <> '' then
        AddSegment(skHeading, SegText);
      if (P <= Length(S)) and (S[P] = #13) then Inc(P);
      if (P <= Length(S)) and (S[P] = #10) then Inc(P);
    end
    else if MatchMarker(S, P, 'q') or MatchMarker(S, P, 'q2') then
    begin
      { \q / \q2 — poetry markers, treat as line break }
      P := P + 2; { skip \q }
      if (P <= Length(S)) and (S[P] in ['1'..'4']) then
        Inc(P);
      if (P <= Length(S)) and (S[P] = ' ') then
        Inc(P);
    end
    else if MatchMarker(S, P, 'p') then
    begin
      { \p — paragraph marker, treat as line break }
      P := P + 2;
      if (P <= Length(S)) and (S[P] = ' ') then
        Inc(P);
    end
    else if MatchMarker(S, P, 'c') then
    begin
      { \c N — chapter marker, skip }
      P := P + 2;
      if (P <= Length(S)) and (S[P] = ' ') then
        Inc(P);
      while (P <= Length(S)) and (S[P] in ['0'..'9']) do
        Inc(P);
      if (P <= Length(S)) and (S[P] = ' ') then
        Inc(P);
    end
    else
    begin
      { Unknown marker — skip the backslash and emit as text }
      Start := P;
      Inc(P);
      while (P <= Length(S)) and (S[P] <> '\') and not (S[P] in [#10, #13]) do
        Inc(P);
      SegText := Copy(S, Start, P - Start);
      if Trim(SegText) <> '' then
        AddSegment(skText, SegText);
    end;
  end;
end;

function TVerseDisplay.CalcNeededHeight(AWidth: Integer): Integer;
var
  Bmp: TBitmap;
begin
  { Use a temporary bitmap to measure text without needing a valid handle }
  Bmp := TBitmap.Create;
  try
    Bmp.Canvas.Font.Assign(Font);
    Result := DoLayout(Bmp.Canvas, AWidth, False);
  finally
    Bmp.Free;
  end;
end;

procedure TVerseDisplay.DrawWordWrapped(ACanvas: TCanvas; const AText: string;
  var X, Y: Integer; MaxW, LineH, SpaceW: Integer; ADraw: Boolean);
var
  Lines: TStringList;
  Words: TStringList;
  Word: string;
  J, WordW: Integer;
begin
  Lines := TStringList.Create;
  try
    Lines.Text := AText;
    for J := 0 to Lines.Count - 1 do
    begin
      if J > 0 then
      begin
        X := 4;
        Y := Y + LineH;
      end;

      Words := TStringList.Create;
      try
        Words.Delimiter := ' ';
        Words.StrictDelimiter := True;
        Words.DelimitedText := Lines[J];

        while Words.Count > 0 do
        begin
          Word := Words[0];
          Words.Delete(0);
          if Word = '' then
            Continue;

          WordW := ACanvas.TextWidth(Word);
          if (X > 4) and (X + WordW > MaxW) then
          begin
            X := 4;
            Y := Y + LineH;
          end;
          if ADraw then
          begin
            ACanvas.Brush.Color := Self.Color;
            ACanvas.TextOut(X, Y + 1, Word);
          end;
          X := X + WordW + SpaceW;
        end;
      finally
        Words.Free;
      end;
    end;
  finally
    Lines.Free;
  end;
end;

function TVerseDisplay.DoLayout(ACanvas: TCanvas; AWidth: Integer;
  ADraw: Boolean): Integer;
var
  X, Y, MaxW, LineH, BadgeW, BadgeH, BadgePad, SpaceW: Integer;
  I: Integer;
  SavedStyle: TFontStyles;
  SavedHeight: Integer;
  SavedColor: TColor;
const
  FootnoteChar = #$E2#$80#$A0; { dagger character U+2020 }
begin
  ACanvas.Font.Assign(Font);
  LineH := ACanvas.TextHeight('Ag') + 4;
  BadgeH := LineH - 2;
  BadgePad := 5;
  SpaceW := ACanvas.TextWidth(' ');
  MaxW := AWidth - 8;

  X := 4;
  Y := 4;

  for I := 0 to Length(FSegments) - 1 do
  begin
    case FSegments[I].Kind of
      skVerse:
      begin
        { Verse number badge }
        BadgeW := ACanvas.TextWidth(FSegments[I].Text) + BadgePad * 2 + 2;
        if (X > 4) and (X + BadgeW > MaxW) then
        begin
          X := 4;
          Y := Y + LineH;
        end;
        if ADraw then
        begin
          ACanvas.Brush.Color := FBadgeColor;
          ACanvas.Pen.Color := FBadgeColor;
          ACanvas.RoundRect(X, Y, X + BadgeW, Y + BadgeH, 8, 8);
          ACanvas.Font.Color := clWhite;
          ACanvas.Font.Style := [fsBold];
          ACanvas.Brush.Style := bsClear;
          ACanvas.TextOut(X + BadgePad + 1, Y + 1, FSegments[I].Text);
          ACanvas.Brush.Style := bsSolid;
          ACanvas.Font.Color := Self.Font.Color;
          ACanvas.Font.Style := Self.Font.Style;
        end;
        X := X + BadgeW + 4;
      end;

      skFootnote:
      begin
        { Small footnote indicator badge }
        BadgeW := ACanvas.TextWidth(FootnoteChar) + 6;
        if (X > 4) and (X + BadgeW > MaxW) then
        begin
          X := 4;
          Y := Y + LineH;
        end;
        if ADraw then
        begin
          ACanvas.Brush.Color := $4080FF;  { orange-red }
          ACanvas.Pen.Color := $4080FF;
          ACanvas.RoundRect(X, Y + 2, X + BadgeW, Y + BadgeH - 2, 6, 6);
          ACanvas.Font.Color := clWhite;
          ACanvas.Font.Style := [fsBold];
          ACanvas.Brush.Style := bsClear;
          ACanvas.TextOut(X + 3, Y + 2, FootnoteChar);
          ACanvas.Brush.Style := bsSolid;
          ACanvas.Font.Color := Self.Font.Color;
          ACanvas.Font.Style := Self.Font.Style;
        end;
        X := X + BadgeW + 3;
      end;

      skHeading:
      begin
        { Section heading: new line, bold, slightly larger }
        if X > 4 then
        begin
          X := 4;
          Y := Y + LineH;
        end;
        SavedStyle := ACanvas.Font.Style;
        SavedHeight := ACanvas.Font.Height;
        ACanvas.Font.Style := [fsBold];
        ACanvas.Font.Height := ACanvas.Font.Height - 2;
        DrawWordWrapped(ACanvas, FSegments[I].Text, X, Y, MaxW, LineH + 2, SpaceW, ADraw);
        ACanvas.Font.Style := SavedStyle;
        ACanvas.Font.Height := SavedHeight;
        { Force new line after heading }
        X := 4;
        Y := Y + LineH;
      end;

      skDescription:
      begin
        { Descriptive title: new line, italic }
        if X > 4 then
        begin
          X := 4;
          Y := Y + LineH;
        end;
        SavedStyle := ACanvas.Font.Style;
        SavedColor := ACanvas.Font.Color;
        ACanvas.Font.Style := [fsItalic];
        ACanvas.Font.Color := $606060;
        DrawWordWrapped(ACanvas, FSegments[I].Text, X, Y, MaxW, LineH, SpaceW, ADraw);
        ACanvas.Font.Style := SavedStyle;
        ACanvas.Font.Color := SavedColor;
        { Force new line after description }
        X := 4;
        Y := Y + LineH;
      end;

      skText:
      begin
        ACanvas.Font.Style := Self.Font.Style;
        ACanvas.Font.Color := Self.Font.Color;
        DrawWordWrapped(ACanvas, FSegments[I].Text, X, Y, MaxW, LineH, SpaceW, ADraw);
      end;
    end;
  end;

  Result := Y + LineH + 6;
end;

procedure TVerseDisplay.Paint;
var
  R: TRect;
begin
  R := ClientRect;
  Canvas.Brush.Color := Color;
  Canvas.FillRect(R);
  { Clip drawing to control bounds so text cannot overflow right edge }
  IntersectClipRect(Canvas.Handle, R.Left, R.Top, R.Right, R.Bottom);
  try
    if Length(FSegments) > 0 then
      DoLayout(Canvas, Width, True);
  finally
    SelectClipRgn(Canvas.Handle, 0);
  end;
end;

{ ---- TProjectEditWindow ---- }

procedure TProjectEditWindow.FormCreate(Sender: TObject);
begin
  LogFmt(llInfo, 'ProjectEditForm.FormCreate self=%p', [Pointer(Self)]);
  FProject := nil;
  FSourceRC := nil;
  FCurrentChapterIndex := -1;
  FLastSourcePos := 0;
  FLastTransPos := 0;
  FSyncingScroll := False;
  FSelectedChunkIndex := -1;
  FActiveResourceTab := rtNotes;
  FLayoutDirection := 'ltr';
  ApplyFontRecursive(Self, 'Noto Sans');
  btnMenu.OnClick := @btnMenuClick;

  SourceScrollBox.VertScrollBar.Smooth := True;
  TransScrollBox.VertScrollBar.Smooth := True;

  SourceScrollBox.OnMouseWheel := @PaneMouseWheel;
  TransScrollBox.OnMouseWheel := @PaneMouseWheel;
  btnTabNotes.OnClick := @OnResourceTabClick;
  btnTabWords.OnClick := @OnResourceTabClick;
  btnTabQuestions.OnClick := @OnResourceTabClick;
  btnChangeSource.OnClick := @btnChangeSourceClick;
  Splitter1.OnMoved := @SplitterMoved;
  Splitter2.OnMoved := @SplitterMoved;

  FScrollSyncTimer := TTimer.Create(Self);
  FScrollSyncTimer.Interval := 30;
  FScrollSyncTimer.OnTimer := @ScrollSyncTimerFire;
  FScrollSyncTimer.Enabled := True;
  ApplyTheme;
  ApplyOrientationLayout(FLayoutDirection);
  UpdatePaneHeaders;
end;

procedure TProjectEditWindow.RecalcAllChunkLayouts;
var
  I: Integer;
begin
  for I := 0 to Length(FChunkPanels) - 1 do
    FChunkPanels[I].RecalcLayout;
end;

procedure TProjectEditWindow.ScheduleRecalcLayout;
begin
  if FRecalcTimer = nil then
  begin
    FRecalcTimer := TTimer.Create(Self);
    FRecalcTimer.Interval := 50;
    FRecalcTimer.OnTimer := @RecalcLayoutTimerFire;
  end;
  { Restart the timer on each resize event so we only fire once after settling }
  FRecalcTimer.Enabled := False;
  FRecalcTimer.Enabled := True;
end;

procedure TProjectEditWindow.RecalcLayoutTimerFire(Sender: TObject);
begin
  FRecalcTimer.Enabled := False;
  RecalcAllChunkLayouts;
end;

procedure TProjectEditWindow.FormResize(Sender: TObject);
begin
  ApplyOrientationLayout(FLayoutDirection);
  UpdatePaneHeaders;
  ScheduleRecalcLayout;
end;

procedure TProjectEditWindow.SplitterMoved(Sender: TObject);
begin
  ScheduleRecalcLayout;
end;

procedure TProjectEditWindow.btnMenuClick(Sender: TObject);
var
  OldTheme, NewTheme: TAppTheme;
  OldSuite, NewSuite: string;
begin
  if ShowSettingsDialog(OldTheme, NewTheme, OldSuite, NewSuite) then
  begin
    if NewTheme <> OldTheme then
      ApplyTheme;
  end;
end;

procedure TProjectEditWindow.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  LogFmt(llInfo, 'ProjectEditForm.FormClose self=%p', [Pointer(Self)]);
  if FScrollSyncTimer <> nil then
    FScrollSyncTimer.Enabled := False;
  AutoSaveTimer.Enabled := False;
  try
    LogInfo('ProjectEditForm.FormClose: saving current chapter');
    SaveCurrentChapter;
  except
    on E: Exception do
      LogFmt(llWarn, 'ProjectEditForm.FormClose: save failed: %s', [E.Message]);
  end;
  LogInfo('ProjectEditForm.FormClose: clearing chunk panels');
  ClearChunkPanels;
  LogInfo('ProjectEditForm.FormClose: freeing FProject and FSourceRC');
  FreeAndNil(FProject);
  FreeAndNil(FSourceRC);
  LogInfo('ProjectEditForm.FormClose: done, setting caHide');
  CloseAction := caHide;
end;

procedure TProjectEditWindow.btnBackClick(Sender: TObject);
begin
  Close;
end;

procedure TProjectEditWindow.btnPrevChapterClick(Sender: TObject);
begin
  try
    if FCurrentChapterIndex > 0 then
      LoadChapter(FCurrentChapterIndex - 1);
  except
    on E: Exception do
    begin
      ShowMessage(rsErrorOpeningChapterPrefix + E.Message +
        LineEnding + rsReturningHomeScreen);
      Close;
    end;
  end;
end;

procedure TProjectEditWindow.btnNextChapterClick(Sender: TObject);
begin
  try
    if (FSourceRC <> nil) and
       (FCurrentChapterIndex < FSourceRC.Book.Chapters.Count - 1) then
      LoadChapter(FCurrentChapterIndex + 1);
  except
    on E: Exception do
    begin
      ShowMessage(rsErrorOpeningChapterPrefix + E.Message +
        LineEnding + rsReturningHomeScreen);
      Close;
    end;
  end;
end;

procedure TProjectEditWindow.AutoSaveTimerFire(Sender: TObject);
begin
  try
    SaveCurrentChapter;
    lblStatus.Caption := rsAutoSavedAtPrefix + TimeToStr(Now);
  except
    on E: Exception do
    begin
      ShowMessage(rsAutoSaveFailedPrefix + E.Message +
        LineEnding + rsReturningHomeScreen);
      Close;
    end;
  end;
end;

function TProjectEditWindow.IsControlInPane(AControl: TControl; APane: TWinControl): Boolean;
begin
  Result := False;
  while AControl <> nil do
  begin
    if AControl = APane then
      Exit(True);
    AControl := AControl.Parent;
  end;
end;

procedure TProjectEditWindow.PaneMouseWheel(Sender: TObject; Shift: TShiftState;
  WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
var
  BasePos, NewPos, PixelStep: Integer;
begin
  if FSyncingScroll then
    Exit;

  PixelStep := Round((WheelDelta / 120.0) * 48.0);
  if PixelStep = 0 then
    Exit;

  if (Sender is TControl) and
     IsControlInPane(TControl(Sender), TransScrollBox) then
    BasePos := TransScrollBox.VertScrollBar.Position
  else
    BasePos := SourceScrollBox.VertScrollBar.Position;

  NewPos := BasePos - PixelStep;
  if NewPos < 0 then
    NewPos := 0;

  FSyncingScroll := True;
  try
    SourceScrollBox.VertScrollBar.Position := NewPos;
    TransScrollBox.VertScrollBar.Position := NewPos;
    FLastSourcePos := SourceScrollBox.VertScrollBar.Position;
    FLastTransPos := TransScrollBox.VertScrollBar.Position;
  finally
    FSyncingScroll := False;
  end;

  Handled := True;
end;

procedure TProjectEditWindow.ScrollSyncTimerFire(Sender: TObject);
var
  SourcePos, TransPos, NewPos: Integer;
begin
  if FSyncingScroll then
    Exit;

  SourcePos := SourceScrollBox.VertScrollBar.Position;
  TransPos := TransScrollBox.VertScrollBar.Position;
  if SourcePos = TransPos then
  begin
    FLastSourcePos := SourcePos;
    FLastTransPos := TransPos;
    Exit;
  end;

  if SourcePos <> FLastSourcePos then
    NewPos := SourcePos
  else if TransPos <> FLastTransPos then
    NewPos := TransPos
  else
    NewPos := SourcePos;

  FSyncingScroll := True;
  try
    SourceScrollBox.VertScrollBar.Position := NewPos;
    TransScrollBox.VertScrollBar.Position := NewPos;
  finally
    FSyncingScroll := False;
  end;

  FLastSourcePos := SourceScrollBox.VertScrollBar.Position;
  FLastTransPos := TransScrollBox.VertScrollBar.Position;
end;

procedure TProjectEditWindow.AttachWheelHandlers(AParent: TWinControl);
var
  I: Integer;
begin
  if AParent = nil then
    Exit;

  AParent.RemoveHandlerOnMouseWheel(@PaneMouseWheel);
  AParent.AddHandlerOnMouseWheel(@PaneMouseWheel, True);
  for I := 0 to AParent.ControlCount - 1 do
  begin
    if AParent.Controls[I] is TControl then
    begin
      TControl(AParent.Controls[I]).RemoveHandlerOnMouseWheel(@PaneMouseWheel);
      TControl(AParent.Controls[I]).AddHandlerOnMouseWheel(@PaneMouseWheel, True);
    end;
    if AParent.Controls[I] is TWinControl then
      AttachWheelHandlers(TWinControl(AParent.Controls[I]));
  end;
end;

function ReadSourceLanguageName(const SourceBaseDir: string): string;
var
  PkgPath: string;
  SL: TStringList;
  Data: TJSONData;
  Obj: TJSONObject;
  LangNode: TJSONData;
begin
  Result := '';
  PkgPath := IncludeTrailingPathDelimiter(SourceBaseDir) + 'package.json';
  if not FileExists(PkgPath) then
    Exit;
  SL := TStringList.Create;
  try
    SL.LoadFromFile(PkgPath);
    Data := nil;
    try
      Data := GetJSON(SL.Text);
      if Data is TJSONObject then
      begin
        Obj := TJSONObject(Data);
        LangNode := Obj.FindPath('language.name');
        if LangNode <> nil then
          Result := LangNode.AsString;
      end;
    except
      { ignore }
    end;
    Data.Free;
  finally
    SL.Free;
  end;
end;

function PromptForSourceChange(const BookCode, CurrentLangCode, CurrentResourceType: string;
  out SelectedSourceDir: string): Boolean;
var
  LibPath, DirName, FullPath, PkgFile: string;
  SR: TSearchRec;
  JsonData: TJSONData;
  JsonObj, LangObj, ResObj: TJSONObject;
  LangSlug, LangName, ResSlug, ResName, DisplayStr: string;
  DisplayList, DirList: TStringList;
  SL: TStringList;
  Dlg: TForm;
  ListBox: TListBox;
  BtnPanel: TPanel;
  BtnOK, BtnCancel: TButton;
  I, J, SelIdx: Integer;
  MatchPattern: string;
  InstalledKeys: TStringList;
  DB: TIndexDatabase;
  Resources: TResourceInfoArray;
  TsrcSlug, ZipPath, DestDir, ErrMsg: string;
  SourceOpt: TSourceTextOption;
begin
  Result := False;
  SelectedSourceDir := '';
  LibPath := GetLibraryPath;
  DisplayList := TStringList.Create;
  DirList := TStringList.Create;
  InstalledKeys := TStringList.Create;
  try
    MatchPattern := '_' + LowerCase(BookCode) + '_';

    { First, scan installed source texts }
    if FindFirst(LibPath + '*', faDirectory, SR) = 0 then
    begin
      try
        repeat
          if (SR.Attr and faDirectory) = 0 then
            Continue;
          if (SR.Name = '.') or (SR.Name = '..') then
            Continue;
          DirName := SR.Name;
          if Pos(MatchPattern, LowerCase(DirName)) = 0 then
            Continue;

          FullPath := LibPath + DirName;
          PkgFile := IncludeTrailingPathDelimiter(FullPath) + 'package.json';
          if not FileExists(PkgFile) then
            Continue;

          LangSlug := ''; LangName := ''; ResSlug := ''; ResName := '';
          SL := TStringList.Create;
          try
            SL.LoadFromFile(PkgFile);
            JsonData := nil;
            try
              JsonData := GetJSON(SL.Text);
              if JsonData is TJSONObject then
              begin
                JsonObj := TJSONObject(JsonData);
                if JsonObj.Find('language') is TJSONObject then
                begin
                  LangObj := TJSONObject(JsonObj.Find('language'));
                  LangSlug := LangObj.Get('slug', '');
                  LangName := LangObj.Get('name', '');
                end;
                if JsonObj.Find('resource') is TJSONObject then
                begin
                  ResObj := TJSONObject(JsonObj.Find('resource'));
                  ResSlug := ResObj.Get('slug', '');
                  ResName := ResObj.Get('name', '');
                end;
              end;
            except
              { skip malformed JSON }
            end;
            JsonData.Free;
          finally
            SL.Free;
          end;

          DisplayStr := LangSlug + ' - ' + LangName + '  |  ' + ResSlug + ' - ' + ResName;
          DisplayList.Add(DisplayStr);
          DirList.Add(FullPath);
          InstalledKeys.Add(LowerCase(LangSlug) + '_' + LowerCase(BookCode) + '_' + LowerCase(ResSlug));
        until FindNext(SR) <> 0;
      finally
        FindClose(SR);
      end;
    end;

    { Next, add available-but-not-installed sources from index database }
    DB := IndexDatabase.OpenIndexDatabase;
    if DB <> nil then
    begin
      try
        Resources := DB.ListSourceTexts(LowerCase(BookCode));
        for I := 0 to High(Resources) do
        begin
          TsrcSlug := LowerCase(Resources[I].SourceLangSlug) + '_' +
            LowerCase(BookCode) + '_' + LowerCase(Resources[I].Slug);
          if InstalledKeys.IndexOf(TsrcSlug) >= 0 then
            Continue;  { already in the installed list }

          DisplayStr := Resources[I].SourceLangSlug + ' - ' + Resources[I].SourceLangName +
            '  |  ' + Resources[I].Slug + ' - ' + Resources[I].Name +
            '  [not installed]';
          DisplayList.Add(DisplayStr);
          { Use a marker prefix so we know to extract on selection }
          DirList.Add('extract:' + TsrcSlug);
        end;
      finally
        DB.Free;
      end;
    end;

    if DisplayList.Count = 0 then
    begin
      MessageDlg('No source texts found for "' + BookCode + '".',
        mtInformation, [mbOK], 0);
      Exit;
    end;

    { Sort both lists together }
    for I := 0 to DisplayList.Count - 2 do
      for J := I + 1 to DisplayList.Count - 1 do
        if CompareText(DisplayList[I], DisplayList[J]) > 0 then
        begin
          DisplayList.Exchange(I, J);
          DirList.Exchange(I, J);
        end;

    { Build dialog }
    Dlg := TForm.CreateNew(nil);
    try
      Dlg.Caption := 'Select Source Text';
      Dlg.Width := 600;
      Dlg.Height := 450;
      Dlg.Position := poScreenCenter;
      Dlg.BorderStyle := bsDialog;

      BtnPanel := TPanel.Create(Dlg);
      BtnPanel.Parent := Dlg;
      BtnPanel.Align := alBottom;
      BtnPanel.Height := 45;
      BtnPanel.BevelOuter := bvNone;

      BtnOK := TButton.Create(Dlg);
      BtnOK.Parent := BtnPanel;
      BtnOK.Caption := 'OK';
      BtnOK.ModalResult := mrOK;
      BtnOK.Default := True;
      BtnOK.Width := 80;
      BtnOK.Left := 600 - 80 - 12 - 80 - 8;
      BtnOK.Top := 8;

      BtnCancel := TButton.Create(Dlg);
      BtnCancel.Parent := BtnPanel;
      BtnCancel.Caption := 'Cancel';
      BtnCancel.ModalResult := mrCancel;
      BtnCancel.Width := 80;
      BtnCancel.Left := 600 - 80 - 12;
      BtnCancel.Top := 8;

      ListBox := TListBox.Create(Dlg);
      ListBox.Parent := Dlg;
      ListBox.Align := alClient;

      for I := 0 to DisplayList.Count - 1 do
        ListBox.Items.Add(DisplayList[I]);

      { Pre-select current source }
      SelIdx := -1;
      for I := 0 to DirList.Count - 1 do
      begin
        DirName := ExtractFileName(DirList[I]);
        if (Pos(LowerCase(CurrentLangCode) + '_', LowerCase(DirName)) = 1) and
           (Pos('_' + LowerCase(CurrentResourceType), LowerCase(DirName)) > 0) then
        begin
          SelIdx := I;
          Break;
        end;
      end;
      if SelIdx >= 0 then
        ListBox.ItemIndex := SelIdx
      else if ListBox.Items.Count > 0 then
        ListBox.ItemIndex := 0;

      if Dlg.ShowModal = mrOK then
        if ListBox.ItemIndex >= 0 then
        begin
          FullPath := DirList[ListBox.ItemIndex];

          if Pos('extract:', FullPath) = 1 then
          begin
            { Need to extract this source text first }
            TsrcSlug := Copy(FullPath, Length('extract:') + 1, MaxInt);
            DestDir := IncludeTrailingPathDelimiter(LibPath) + TsrcSlug;

            ZipPath := SourceExtractor.FindBundledZipPath;
            if ZipPath = '' then
              ZipPath := GetBundledResourceContainersZipPath;
            if (ZipPath = '') or (not FileExists(ZipPath)) then
            begin
              MessageDlg('Bundled resource archive not found.', mtError, [mbOK], 0);
              Exit;
            end;

            ForceDirectories(DestDir);
            LogFmt(llInfo, 'Extracting source for change: %s', [TsrcSlug]);

            if not SourceExtractor.ExtractTsrc(ZipPath, TsrcSlug, DestDir) then
            begin
              MessageDlg('Failed to extract source text: ' + TsrcSlug,
                mtError, [mbOK], 0);
              Exit;
            end;

            SelectedSourceDir := DestDir;
          end
          else
            SelectedSourceDir := FullPath;

          Result := True;
        end;
    finally
      Dlg.Free;
    end;
  finally
    InstalledKeys.Free;
    DisplayList.Free;
    DirList.Free;
  end;
end;

procedure TProjectEditWindow.ShowLoadingSplash(const AText: string);
var
  Pal: TThemePalette;
  ContentPanel: TPanel;
begin
  if FLoadingSplash <> nil then
    Exit;

  Pal := GetThemePalette(GetEffectiveTheme);

  FLoadingSplash := TForm.Create(Self);
  FLoadingSplash.BorderStyle := bsNone;
  FLoadingSplash.BorderIcons := [];
  FLoadingSplash.Position := poScreenCenter;
  FLoadingSplash.Font.Name := 'Noto Sans';
  FLoadingSplash.Color := Pal.PanelBG;
  FLoadingSplash.ClientWidth := 380;
  FLoadingSplash.ClientHeight := 100;

  ContentPanel := TPanel.Create(FLoadingSplash);
  ContentPanel.Parent := FLoadingSplash;
  ContentPanel.Align := alClient;
  ContentPanel.BevelOuter := bvNone;
  ContentPanel.Color := Pal.PanelBG;
  ContentPanel.ParentBackground := False;
  ContentPanel.ParentColor := False;

  FLoadingLabel := TLabel.Create(ContentPanel);
  FLoadingLabel.Parent := ContentPanel;
  FLoadingLabel.AutoSize := False;
  FLoadingLabel.Alignment := taCenter;
  FLoadingLabel.SetBounds(0, 20, 380, 24);
  FLoadingLabel.Font.Height := -14;
  FLoadingLabel.Font.Name := 'Noto Sans';
  FLoadingLabel.Font.Color := Pal.TextPrimary;
  FLoadingLabel.Caption := AText;

  FLoadingBar := TProgressBar.Create(ContentPanel);
  FLoadingBar.Parent := ContentPanel;
  FLoadingBar.SetBounds(40, 58, 300, 22);
  FLoadingBar.Min := 0;
  FLoadingBar.Max := 100;
  FLoadingBar.Position := 0;
  FLoadingBar.Style := pbstNormal;

  FLoadingSplash.Show;
  FLoadingSplash.Update;
end;

procedure TProjectEditWindow.UpdateLoadingSplash(const AText: string;
  AProgress: Integer);
begin
  if FLoadingSplash = nil then
    Exit;
  if FLoadingLabel <> nil then
    FLoadingLabel.Caption := AText;
  if FLoadingBar <> nil then
    FLoadingBar.Position := AProgress;
  FLoadingSplash.Update;
end;

procedure TProjectEditWindow.HideLoadingSplash;
begin
  if FLoadingSplash <> nil then
  begin
    FLoadingSplash.Hide;
    FreeAndNil(FLoadingSplash);
    FLoadingLabel := nil;
    FLoadingBar := nil;
  end;
end;

procedure TProjectEditWindow.OpenProject(const APath: string;
  const ASummary: TProjectSummary);
var
  SourceOpt: TSourceTextOption;
  SourceBaseDir, SourceErr, SourceResourceID, Direction: string;
begin
  LogFmt(llInfo, 'ProjectEditForm.OpenProject self=%p path=%s book=%s',
    [Pointer(Self), APath, ASummary.BookCode]);
  ShowLoadingSplash(rsLoadingProject);
  try
    FProjectPath := APath;
    FSummary := ASummary;

    { Load project manifest first so we can resolve exact source language/resource. }
    UpdateLoadingSplash(rsLoadingProject, 10);
    FProject := TProject.Create(APath);
    SourceResourceID := FProject.GetSourceResourceType;
    if SourceResourceID = '' then
      SourceResourceID := 'ulb';
    Direction := FProject.GetTargetLanguageDirection;
    FLayoutDirection := Direction;
    ApplyOrientationLayout(FLayoutDirection);

    SourceOpt.SourceDir := '';
    SourceOpt.SourceLangCode := FProject.GetSourceLanguageCode;
    SourceOpt.SourceLangName := '';
    SourceOpt.BookCode := FProject.BookCode;
    SourceOpt.BookName := ASummary.BookName;
    SourceOpt.ResourceID := SourceResourceID;
    SourceOpt.ResourceName := '';
    if SourceOpt.SourceLangCode = '' then
      SourceOpt.SourceLangCode := 'en';
    FSourceLangCode := SourceOpt.SourceLangCode;
    FSourceResourceType := SourceResourceID;
    FBookCode := ASummary.BookCode;

    if not EnsureSourceTextPresent(SourceOpt, SourceBaseDir, SourceErr) then
    begin
      HideLoadingSplash;
      ShowMessage(rsCannotPrepareSourceTextPrefix + ASummary.BookCode + rsCannotPrepareSourceTextMid +
        SourceErr);
      Close;
      Exit;
    end;

    FSourceContentDir := IncludeTrailingPathDelimiter(SourceBaseDir) + 'content';
    if not DirectoryExists(FSourceContentDir) then
      FSourceContentDir := FindSourceContentDir(ASummary);
    if FSourceContentDir = '' then
    begin
      HideLoadingSplash;
      ShowMessage(rsCannotFindSourceTextContentPrefix + ASummary.BookCode +
        rsCannotFindSourceTextContentSuffix);
      Close;
      Exit;
    end;

    { Find English ULB for save-chunking }
    FEnglishULBContentDir := FindEnglishULBContentDir(ASummary.BookCode);

    { Load source resource container }
    UpdateLoadingSplash(rsLoadingSourceText, 30);
    FSourceRC := TResourceContainer.Create('', ASummary.BookCode, SourceResourceID, '');
    FSourceRC.Book.LoadFromToc(FSourceContentDir);
    FSourceRC.Book.LoadContent(FSourceContentDir, '.usx');

    { Load project content }
    UpdateLoadingSplash(rsLoadingTranslation, 60);
    FProject.LoadContent(FSourceContentDir);

    { Set up title and headers }
    Caption := ASummary.BookName + ' - ' + ASummary.TargetLangName +
      ' (' + ASummary.TargetLangCode + ')';
    lblProjectTitle.Caption := Caption;
    lblSourceHeader.Caption := rsSourceTextHeader;
    SourceLangHeader.Caption := ReadSourceLanguageName(SourceBaseDir) +
      ' ' + UpperCase(SourceResourceID);
    if Trim(SourceLangHeader.Caption) = UpperCase(SourceResourceID) then
      SourceLangHeader.Caption := SourceOpt.SourceLangCode + ' ' + UpperCase(SourceResourceID);

    if CanonicalBookName(ASummary.BookCode) <> '' then
      lblTransHeader.Caption := CanonicalBookName(ASummary.BookCode)
    else
      lblTransHeader.Caption := ASummary.BookName;
    lblTransLangHeader.Caption := ASummary.TargetLangName +
      ' (' + ASummary.TargetLangCode + ')';

    UpdatePaneHeaders;

    AutoSaveTimer.Enabled := True;

    { Load first chapter (skip 'front' if present) }
    UpdateLoadingSplash(rsLoadingChapter, 85);
    if FSourceRC.Book.Chapters.Count > 0 then
    begin
      if (FSourceRC.Book.Chapters.Count > 1) and
         (FSourceRC.Book.Chapters[0].ID = 'front') then
        LoadChapter(1)
      else
        LoadChapter(0);
    end;

    HideLoadingSplash;
  except
    on E: Exception do
    begin
      HideLoadingSplash;
      AutoSaveTimer.Enabled := False;
      raise Exception.Create(rsUnableToOpenProjectPrefix + ASummary.BookName +
        rsUnableToOpenProjectMid + E.Message);
    end;
  end;
end;

procedure TProjectEditWindow.ApplyOrientationLayout(const Direction: string);
var
  IsRTL: Boolean;
begin
  IsRTL := SameText(Trim(Direction), 'rtl');

  if IsRTL then
  begin
    BiDiMode := bdRightToLeft;
    LeftRail.Align := alRight;
    SplitPanel.Align := alClient;

    { Mirror inner panes so source stays beside sidebar (on the right). }
    ResourcePanel.Align := alLeft;
    Splitter2.Align := alLeft;
    SourcePanel.Align := alRight;
    Splitter1.Align := alRight;
    TransPanel.Align := alClient;
  end
  else
  begin
    BiDiMode := bdLeftToRight;
    LeftRail.Align := alLeft;
    SplitPanel.Align := alClient;

    { LTR defaults: source on left, resources on right. }
    SourcePanel.Align := alLeft;
    Splitter1.Align := alLeft;
    ResourcePanel.Align := alRight;
    Splitter2.Align := alRight;
    TransPanel.Align := alClient;
  end;
end;

procedure TProjectEditWindow.UpdatePaneHeaders;
var
  SourceLeft, TransLeft, ResLeft: Integer;
  TabGap: Integer;
begin
  { Position header labels above their respective panes }
  SourceLeft := SourcePanel.Left + 8;
  TransLeft := TransPanel.Left + 8;
  ResLeft := ResourcePanel.Left;

  lblSourceHeader.Left := SourceLeft;
  lblSourceHeader.Top := 2;
  SourceLangHeader.Left := SourceLeft;
  SourceLangHeader.Top := 19;
  btnChangeSource.Left := SourceLeft + lblSourceHeader.Width + 12;
  btnChangeSource.Top := 2;
  btnChangeSource.Height := 18;
  btnChangeSource.Width := 60;
  btnChangeSource.Font.Height := -10;

  lblTransHeader.Left := TransLeft;
  lblTransHeader.Top := 2;
  lblTransLangHeader.Left := TransLeft;
  lblTransLangHeader.Top := 19;

  { Resource tabs aligned to resource pane }
  TabGap := 4;
  btnTabNotes.Left := ResLeft + TabGap;
  btnTabNotes.Top := 6;
  btnTabWords.Left := btnTabNotes.Left + btnTabNotes.Width + TabGap;
  btnTabWords.Top := 6;
  btnTabQuestions.Left := btnTabWords.Left + btnTabWords.Width + TabGap;
  btnTabQuestions.Top := 6;
end;

procedure TProjectEditWindow.ApplyTheme;
var
  P: TThemePalette;
begin
  P := GetThemePalette(GetEffectiveTheme);

  Color := P.WindowBg;
  TopPanel.Color := P.HeaderBg;
  StatusPanel.Color := P.HeaderBg;
  LeftRail.Color := P.RailBg;
  SplitPanel.Color := P.ContentBg;
  PaneHeaderBar.Color := P.PrimaryLight;
  PaneHeaderBar.ParentBackground := False;
  PaneHeaderBar.ParentColor := False;
  SourcePanel.Color := P.SecondaryPanelBg;
  TransPanel.Color := P.PanelBg;
  ResourcePanel.Color := P.SecondaryPanelBg;
  ResourceMemo.Color := P.MemoBg;
  ResourceMemo.Font.Color := P.TextSecondary;
  lblProjectTitle.Font.Color := P.HeaderText;
  lblChapterNav.Font.Color := P.HeaderText;
  lblChapterNum.Font.Color := P.HeaderText;
  lblSourceHeader.Font.Color := P.TextPrimary;
  SourceLangHeader.Font.Color := P.TextSecondary;
  lblTransHeader.Font.Color := P.TextPrimary;
  lblTransLangHeader.Font.Color := P.TextSecondary;
  lblStatus.Font.Color := P.HeaderText;
  btnMenu.Font.Color := P.RailText;
end;

procedure TProjectEditWindow.btnChangeSourceClick(Sender: TObject);
var
  NewSourceDir, NewContentDir, NewLangName, NewResType: string;
  LangCode, BookCode, ResType: string;
begin
  if not PromptForSourceChange(FBookCode, FSourceLangCode, FSourceResourceType, NewSourceDir) then
    Exit;

  { Save current work before switching }
  SaveCurrentChapter;

  { Parse the selected directory name for lang/resource info }
  if not TResourceContainer.ParseDirName(ExtractFileName(NewSourceDir),
    LangCode, BookCode, ResType) then
    Exit;

  NewContentDir := IncludeTrailingPathDelimiter(NewSourceDir) + 'content';
  if not DirectoryExists(NewContentDir) then
  begin
    ShowMessage('Content directory not found in selected source.');
    Exit;
  end;

  { Update source }
  FSourceLangCode := LangCode;
  FSourceResourceType := ResType;
  FSourceContentDir := NewContentDir;
  FEnglishULBContentDir := FindEnglishULBContentDir(FBookCode);

  FreeAndNil(FSourceRC);
  FSourceRC := TResourceContainer.Create(LangCode, FBookCode, ResType, '');
  FSourceRC.Book.LoadFromToc(FSourceContentDir);
  FSourceRC.Book.LoadContent(FSourceContentDir, '.usx');

  { Reload project content with new source chunking }
  FProject.LoadContent(FSourceContentDir);

  { Update header }
  NewLangName := ReadSourceLanguageName(NewSourceDir);
  if NewLangName = '' then
    NewLangName := LangCode;
  SourceLangHeader.Caption := NewLangName + ' ' + UpperCase(ResType);
  UpdatePaneHeaders;

  { Reload current chapter }
  LoadChapter(FCurrentChapterIndex);
end;

procedure TProjectEditWindow.ClearChunkPanels;
var
  I: Integer;
begin
  LogFmt(llInfo, 'ClearChunkPanels: %d panels, source controls=%d, trans controls=%d',
    [Length(FChunkPanels), SourceScrollBox.ControlCount, TransScrollBox.ControlCount]);
  { Disable layout during bulk removal to prevent intermediate overflow }
  SourceScrollBox.DisableAutoSizing;
  TransScrollBox.DisableAutoSizing;
  try
    for I := 0 to Length(FChunkPanels) - 1 do
      FChunkPanels[I].Free;
    SetLength(FChunkPanels, 0);

    LogFmt(llDebug, 'ClearChunkPanels: after panel free, source orphans=%d, trans orphans=%d',
      [SourceScrollBox.ControlCount, TransScrollBox.ControlCount]);
    { Safety: remove any orphaned controls }
    while SourceScrollBox.ControlCount > 0 do
      SourceScrollBox.Controls[0].Free;
    while TransScrollBox.ControlCount > 0 do
      TransScrollBox.Controls[0].Free;

  finally
    SourceScrollBox.EnableAutoSizing;
    TransScrollBox.EnableAutoSizing;
  end;

  { Reset scroll position }
  SourceScrollBox.VertScrollBar.Position := 0;
  TransScrollBox.VertScrollBar.Position := 0;
end;

procedure TProjectEditWindow.LoadChapter(AIndex: Integer);
var
  SourceChapter, ProjChapter: TChapter;
  I: Integer;
  SourceText, TransText, ChunkLabel: string;
  SourceChunk: TChunk;
  MergedText: string;
  DisplayChunks: TChunkList;
  ChunkMap: TStringList;
  IsFinished: Boolean;
  NextChunkStart: Integer;
begin
  DisplayChunks := nil;
  ChunkMap := nil;
  try
    { Save previous chapter first }
    SaveCurrentChapter;

    FCurrentChapterIndex := AIndex;
    ClearChunkPanels;

    if FSourceRC = nil then
      Exit;
    if (AIndex < 0) or (AIndex >= FSourceRC.Book.Chapters.Count) then
      Exit;

    SourceChapter := FSourceRC.Book.Chapters[AIndex];

    { Get matching project chapter }
    ProjChapter := nil;
    if FProject.Book <> nil then
      ProjChapter := FProject.Book.GetChapter(SourceChapter.ID);

    { Merge project content into single text, then split by source chunking }
    MergedText := '';
    if ProjChapter <> nil then
      MergedText := ProjChapter.MergeAllContent;

    { Build chunk map from source chapter }
    ChunkMap := TStringList.Create;
    for I := 0 to SourceChapter.Chunks.Count - 1 do
      ChunkMap.Add(SourceChapter.Chunks[I].Name);

    { Split project text by source chunking }
    if MergedText <> '' then
      DisplayChunks := SourceChapter.SplitByChunkMap(MergedText, ChunkMap);

    { Build UI panels — disable layout during bulk creation }
    SetLength(FChunkPanels, SourceChapter.Chunks.Count);
    SourceScrollBox.DisableAutoSizing;
    TransScrollBox.DisableAutoSizing;
    try
      for I := 0 to SourceChapter.Chunks.Count - 1 do
      begin
        SourceChunk := SourceChapter.Chunks[I];

        { Convert USX source to plain text }
        SourceText := UsxToPlainText(SourceChunk.Content);

        { Build verse label }
        NextChunkStart := 0;
        if SourceChunk.Name = 'title' then
          ChunkLabel := rsChunkTitle
        else
          ChunkLabel := rsChunkVersePrefix + SourceChunk.Name;
        { Determine verse range }
        if I < SourceChapter.Chunks.Count - 1 then
        begin
          NextChunkStart := StrToIntDef(SourceChapter.Chunks[I + 1].Name, 0);
          if (NextChunkStart > 0) and (StrToIntDef(SourceChunk.Name, 0) > 0) then
          begin
            if NextChunkStart - StrToIntDef(SourceChunk.Name, 0) > 1 then
              ChunkLabel := rsChunkVersePrefix + SourceChunk.Name + rsChunkVerseRangeJoin +
                IntToStr(NextChunkStart - 1);
          end;
        end;

        { Get translated text for this chunk }
        TransText := '';
        if (DisplayChunks <> nil) and (I < DisplayChunks.Count) then
          TransText := DisplayChunks[I].Content;

        { Check if chunk is finished }
        IsFinished := FProject.IsFinished(SourceChapter.ID, SourceChunk.Name);

        FChunkPanels[I] := TChunkPanel.Create(Self,
          SourceScrollBox, TransScrollBox,
          SourceText, TransText, SourceChapter.ID, SourceChunk.Name,
          ChunkLabel, StrToIntDef(SourceChunk.Name, 0),
          NextChunkStart - 1, IsFinished, FProject);
      end;
    finally
      SourceScrollBox.EnableAutoSizing;
      TransScrollBox.EnableAutoSizing;
    end;

    { Recalculate chunk layout now that auto-sizing has set final widths }
    RecalcAllChunkLayouts;

    UpdateChapterNav;
    UpdateStatus;

    { Some controls created during chunk panel build can steal focus and
      auto-scroll mid-chapter. Force both panes back to the first chunk. }
    SourceScrollBox.VertScrollBar.Position := 0;
    TransScrollBox.VertScrollBar.Position := 0;
    FLastSourcePos := 0;
    FLastTransPos := 0;
    AttachWheelHandlers(SourceScrollBox);
    AttachWheelHandlers(TransScrollBox);
    if Length(FChunkPanels) > 0 then
      SetSelectedChunkIndex(0)
    else
      FSelectedChunkIndex := -1;
    ActiveControl := btnBack;
  except
    on E: Exception do
    begin
      ShowMessage(rsErrorRenderingChapterPrefix + E.Message +
        LineEnding + rsReturningHomeScreen);
      Close;
    end;
  end;

  FreeAndNil(DisplayChunks);
  FreeAndNil(ChunkMap);
end;

procedure TProjectEditWindow.SaveCurrentChapter;
var
  I: Integer;
  SourceChapter: TChapter;
  MergedText: string;
  SaveChunks: TChunkList;
  SaveChunkMap: TStringList;
  SaveContentDir: string;
  SaveChapter: TChapter;
  EnglishBook: TBook;
  EnglishChapter: TChapter;
  GitErr: string;
begin
  if FProject = nil then
    Exit;
  if FSourceRC = nil then
    Exit;
  if (FCurrentChapterIndex < 0) or
     (FCurrentChapterIndex >= FSourceRC.Book.Chapters.Count) then
    Exit;

  { Push any editing memo content back to chunks }
  for I := 0 to Length(FChunkPanels) - 1 do
    FChunkPanels[I].SaveContent;

  SourceChapter := FSourceRC.Book.Chapters[FCurrentChapterIndex];

  { Merge display chunks into single text }
  MergedText := '';
  for I := 0 to Length(FChunkPanels) - 1 do
    MergedText := MergedText + FChunkPanels[I].FTransText;

  if MergedText = '' then
  begin
    SaveContentDir := FProject.ProjectDir;
    CleanChapterDir(SaveContentDir + SourceChapter.ID, '.txt');
    CommitProjectChanges(FProject.ProjectDir,
      rsUpdateChapterPrefix + SourceChapter.ID, GitErr);
    Exit;
  end;

  { Determine save chunking: prefer English ULB, fallback to display source }
  SaveChunkMap := TStringList.Create;
  try
    if FEnglishULBContentDir <> '' then
    begin
      EnglishBook := TBook.Create(FProject.BookCode, 'ulb');
      try
        EnglishBook.LoadFromToc(FEnglishULBContentDir);
        EnglishChapter := EnglishBook.GetChapter(SourceChapter.ID);
        if EnglishChapter <> nil then
        begin
          for I := 0 to EnglishChapter.Chunks.Count - 1 do
            SaveChunkMap.Add(EnglishChapter.Chunks[I].Name);
        end;
      finally
        FreeAndNil(EnglishBook);
      end;
    end;

    { Fallback to source chunking if English ULB not found }
    if SaveChunkMap.Count = 0 then
    begin
      for I := 0 to SourceChapter.Chunks.Count - 1 do
        SaveChunkMap.Add(SourceChapter.Chunks[I].Name);
    end;

    { Split merged text by save chunk map }
    SaveChunks := SourceChapter.SplitByChunkMap(MergedText, SaveChunkMap);
    try
      SaveContentDir := FProject.ProjectDir;

      { Delete old chunk files before writing new ones to prevent
        stale files when save chunking differs from load chunking }
      CleanChapterDir(SaveContentDir + SourceChapter.ID, '.txt');

      SaveChapter := TChapter.Create(SourceChapter.ID);
      try
        for I := 0 to SaveChunks.Count - 1 do
        begin
          if Trim(SaveChunks[I].Content) = '' then
            Continue;
          SaveChapter.AddChunk(TChunk.Create(SaveChunks[I].Name));
          SaveChapter.Chunks[SaveChapter.Chunks.Count - 1].Content := SaveChunks[I].Content;
        end;
        SaveChapter.SaveDirtyChunks(SaveContentDir, '.txt');
      finally
        FreeAndNil(SaveChapter);
      end;
    finally
      FreeAndNil(SaveChunks);
    end;
  finally
    FreeAndNil(SaveChunkMap);
  end;

  CommitProjectChanges(FProject.ProjectDir,
    rsUpdateChapterPrefix + SourceChapter.ID, GitErr);
end;

procedure TProjectEditWindow.UpdateStatus;
var
  SourceChapter: TChapter;
  FinCount, I: Integer;
begin
  if (FSourceRC = nil) or (FCurrentChapterIndex < 0) then
    Exit;

  SourceChapter := FSourceRC.Book.Chapters[FCurrentChapterIndex];
  FinCount := 0;
  for I := 0 to SourceChapter.Chunks.Count - 1 do
    if FProject.IsFinished(SourceChapter.ID, SourceChapter.Chunks[I].Name) then
      Inc(FinCount);

  lblStatus.Caption := Format(rsStatusChapterFmt,
    [SourceChapter.ID, FSourceRC.Book.Chapters.Count,
     FinCount, SourceChapter.Chunks.Count]);
end;

procedure TProjectEditWindow.UpdateChapterNav;
begin
  if (FSourceRC = nil) or (FCurrentChapterIndex < 0) then
    Exit;

  lblChapterNum.Caption := FSourceRC.Book.Chapters[FCurrentChapterIndex].ID;
  btnPrevChapter.Enabled := FCurrentChapterIndex > 0;
  btnNextChapter.Enabled := FCurrentChapterIndex < FSourceRC.Book.Chapters.Count - 1;
end;

procedure TProjectEditWindow.OnChunkFinishedChange(Sender: TObject);
var
  CB: TCheckBox;
  I: Integer;
begin
  CB := Sender as TCheckBox;
  if CB.Checked then
  begin
    FProject.MarkFinished(CB.Hint, CB.HelpKeyword);
    { Disable edit for this chunk }
    for I := 0 to Length(FChunkPanels) - 1 do
      if FChunkPanels[I].FFinishedCheck = CB then
      begin
        if FChunkPanels[I].FEditing then
          FChunkPanels[I].SetEditing(False);
        FChunkPanels[I].FEditButton.Enabled := False;
        FChunkPanels[I].FTransDisplay.Font.Color := clGreen;
        FChunkPanels[I].UpdateFinishedVisuals;
        FChunkPanels[I].FTransDisplay.Invalidate;
        Break;
      end;
  end
  else
  begin
    FProject.MarkUnfinished(CB.Hint, CB.HelpKeyword);
    for I := 0 to Length(FChunkPanels) - 1 do
      if FChunkPanels[I].FFinishedCheck = CB then
      begin
        FChunkPanels[I].FEditButton.Enabled := True;
        FChunkPanels[I].FTransDisplay.Font.Color := clBlack;
        FChunkPanels[I].UpdateFinishedVisuals;
        FChunkPanels[I].FTransDisplay.Invalidate;
        Break;
      end;
  end;
  UpdateStatus;
end;

procedure TProjectEditWindow.OnChunkFinishedToggleClick(Sender: TObject);
var
  I: Integer;
begin
  for I := 0 to Length(FChunkPanels) - 1 do
    if FChunkPanels[I].FFinishedToggleBtn = Sender then
    begin
      FChunkPanels[I].FFinishedCheck.Checked := not FChunkPanels[I].FFinishedCheck.Checked;
      Break;
    end;
end;

procedure TProjectEditWindow.OnChunkMemoExit(Sender: TObject);
begin
  SaveCurrentChapter;
  lblStatus.Caption := rsSavedAtPrefix + TimeToStr(Now);
end;

procedure TProjectEditWindow.OnChunkEditClick(Sender: TObject);
var
  Btn: TButton;
  I: Integer;
begin
  Btn := Sender as TButton;
  for I := 0 to Length(FChunkPanels) - 1 do
    if FChunkPanels[I].FEditButton = Btn then
    begin
      FChunkPanels[I].SetEditing(not FChunkPanels[I].FEditing);
      Break;
    end;
end;

procedure TProjectEditWindow.OnChunkPanelClick(Sender: TObject);
var
  I: Integer;
begin
  for I := 0 to Length(FChunkPanels) - 1 do
    if FChunkPanels[I].OwnsControl(Sender) then
    begin
      SetSelectedChunkIndex(I);
      Break;
    end;
end;

procedure TProjectEditWindow.OnResourceTabClick(Sender: TObject);
begin
  if Sender = btnTabNotes then
    FActiveResourceTab := rtNotes
  else if Sender = btnTabWords then
    FActiveResourceTab := rtWords
  else if Sender = btnTabQuestions then
    FActiveResourceTab := rtQuestions;
  UpdateResourcePanelForSelectedChunk;
end;

procedure TProjectEditWindow.SetSelectedChunkIndex(AIndex: Integer);
var
  I: Integer;
begin
  if (AIndex < 0) or (AIndex >= Length(FChunkPanels)) then
    Exit;
  FSelectedChunkIndex := AIndex;
  for I := 0 to Length(FChunkPanels) - 1 do
    FChunkPanels[I].SetSelected(I = AIndex);
  UpdateResourcePanelForSelectedChunk;
end;

function TProjectEditWindow.ResourceDirFor(const ResourceID: string): string;
var
  LangCode: string;
begin
  Result := '';
  if FProject = nil then
    Exit;
  LangCode := FProject.GetSourceLanguageCode;
  if LangCode = '' then
    LangCode := 'en';
  Result := GetLibraryPath + LangCode + '_' + FProject.BookCode + '_' + ResourceID;
  if not DirectoryExists(Result) then
    Result := '';
end;

procedure TProjectEditWindow.CollectChunkResources(const ChapterID: string; ChunkStart,
  ChunkEnd: Integer; const ResourceDir: string; OutList: TStringList);
var
  ChapterDir: string;
  SR: TSearchRec;
  Starts: array of Integer;
  Files: array of string;
  Count, I, J: Integer;
  StartV, EndV: Integer;
  SL: TStringList;
begin
  if (OutList = nil) or (ResourceDir = '') then
    Exit;

  ChapterDir := IncludeTrailingPathDelimiter(ResourceDir) + 'content' +
    DirectorySeparator + ChapterID;
  if not DirectoryExists(ChapterDir) then
    Exit;

  Count := 0;
  if FindFirst(IncludeTrailingPathDelimiter(ChapterDir) + '*.md', faAnyFile, SR) = 0 then
  begin
    repeat
      if (SR.Attr and faDirectory) <> 0 then
        Continue;
      StartV := StrToIntDef(ChangeFileExt(SR.Name, ''), -1);
      if StartV < 0 then
        Continue;
      Inc(Count);
      SetLength(Starts, Count);
      SetLength(Files, Count);
      Starts[Count - 1] := StartV;
      Files[Count - 1] := IncludeTrailingPathDelimiter(ChapterDir) + SR.Name;
    until FindNext(SR) <> 0;
    FindClose(SR);
  end;

  for I := 0 to Count - 2 do
    for J := I + 1 to Count - 1 do
      if Starts[I] > Starts[J] then
      begin
        StartV := Starts[I];
        Starts[I] := Starts[J];
        Starts[J] := StartV;
        ChapterDir := Files[I];
        Files[I] := Files[J];
        Files[J] := ChapterDir;
      end;

  for I := 0 to Count - 1 do
  begin
    StartV := Starts[I];
    if I < Count - 1 then
      EndV := Starts[I + 1] - 1
    else
      EndV := 999;

    if (ChunkStart > 0) and ((ChunkEnd > 0) and ((ChunkEnd < StartV) or (ChunkStart > EndV))) then
      Continue;
    if (ChunkStart > 0) and (ChunkEnd <= 0) and (StartV < ChunkStart) then
      Continue;

    SL := TStringList.Create;
    try
      SL.LoadFromFile(Files[I]);
      if Trim(SL.Text) <> '' then
      begin
        OutList.Add('[' + IntToStr(StartV) + '-' + IntToStr(EndV) + ']');
        OutList.Add(Trim(SL.Text));
        OutList.Add('');
      end;
    finally
      SL.Free;
    end;
  end;
end;

procedure TProjectEditWindow.CollectWordsResources(const ChapterID: string; ChunkStart,
  ChunkEnd: Integer; OutList: TStringList);
var
  ConfigPath, TwDir, RawLine, Line, CurrentChapter, CurrentVerse, WordID, TwFile: string;
  SL, TwText: TStringList;
  I, V, Indent: Integer;
begin
  if (OutList = nil) or (FSourceContentDir = '') then
    Exit;

  ConfigPath := IncludeTrailingPathDelimiter(FSourceContentDir) + 'config.yml';
  TwDir := GetLibraryPath + 'en_bible_tw' + DirectorySeparator + 'content';
  if (not FileExists(ConfigPath)) or (not DirectoryExists(TwDir)) then
    Exit;

  CurrentChapter := '';
  CurrentVerse := '';
  SL := TStringList.Create;
  try
    SL.LoadFromFile(ConfigPath);
    for I := 0 to SL.Count - 1 do
    begin
      RawLine := SL[I];
      Line := Trim(RawLine);
      Indent := Length(RawLine) - Length(TrimLeft(RawLine));
      if (Length(Line) >= 4) and (Line[1] = '''') and (Line[4] = '''') and
         (Line[5] = ':') then
      begin
        if Indent = 2 then
        begin
          CurrentChapter := Copy(Line, 2, 2);
          CurrentVerse := '';
        end
        else if Indent = 4 then
          CurrentVerse := Copy(Line, 2, 2);
      end
      else if Pos('- //bible/tw/', Line) = 1 then
      begin
        if (CurrentChapter <> ChapterID) then
          Continue;
        V := StrToIntDef(CurrentVerse, 0);
        if (ChunkStart > 0) and (V > 0) and (V < ChunkStart) then
          Continue;
        if (ChunkEnd > 0) and (V > ChunkEnd) then
          Continue;

        WordID := Copy(Line, Length('- //bible/tw/') + 1, MaxInt);
        TwFile := IncludeTrailingPathDelimiter(TwDir) + WordID + DirectorySeparator + '01.md';
        if FileExists(TwFile) then
        begin
          TwText := TStringList.Create;
          try
            TwText.LoadFromFile(TwFile);
            if Trim(TwText.Text) <> '' then
            begin
              OutList.Add('[word:' + WordID + ']');
              OutList.Add(Trim(TwText.Text));
              OutList.Add('');
            end;
          finally
            TwText.Free;
          end;
        end;
      end;
    end;
  finally
    SL.Free;
  end;
end;

procedure TProjectEditWindow.UpdateResourcePanelForSelectedChunk;
var
  NotesList, WordsList, QuestionsList, Display: TStringList;
  ChapterID: string;
  StartV, EndV: Integer;
begin
  if (FSelectedChunkIndex < 0) or (FSelectedChunkIndex >= Length(FChunkPanels)) then
  begin
    ResourceMemo.Lines.Text := '';
    Exit;
  end;

  ChapterID := FChunkPanels[FSelectedChunkIndex].FChapterID;
  StartV := FChunkPanels[FSelectedChunkIndex].StartVerse;
  EndV := FChunkPanels[FSelectedChunkIndex].EndVerse;

  NotesList := TStringList.Create;
  WordsList := TStringList.Create;
  QuestionsList := TStringList.Create;
  Display := TStringList.Create;
  try
    CollectChunkResources(ChapterID, StartV, EndV, ResourceDirFor('tn'), NotesList);
    CollectWordsResources(ChapterID, StartV, EndV, WordsList);
    CollectChunkResources(ChapterID, StartV, EndV, ResourceDirFor('tq'), QuestionsList);

    btnTabNotes.Visible := NotesList.Count > 0;
    btnTabWords.Visible := WordsList.Count > 0;
    btnTabQuestions.Visible := QuestionsList.Count > 0;

    if (FActiveResourceTab = rtNotes) and (NotesList.Count = 0) then
      if WordsList.Count > 0 then FActiveResourceTab := rtWords else
      if QuestionsList.Count > 0 then FActiveResourceTab := rtQuestions;
    if (FActiveResourceTab = rtWords) and (WordsList.Count = 0) then
      if NotesList.Count > 0 then FActiveResourceTab := rtNotes else
      if QuestionsList.Count > 0 then FActiveResourceTab := rtQuestions;
    if (FActiveResourceTab = rtQuestions) and (QuestionsList.Count = 0) then
      if NotesList.Count > 0 then FActiveResourceTab := rtNotes else
      if WordsList.Count > 0 then FActiveResourceTab := rtWords;

    case FActiveResourceTab of
      rtNotes: Display.Assign(NotesList);
      rtWords: Display.Assign(WordsList);
      rtQuestions: Display.Assign(QuestionsList);
    end;
    ResourceMemo.Lines.Assign(Display);
  finally
    NotesList.Free;
    WordsList.Free;
    QuestionsList.Free;
    Display.Free;
  end;
end;

{ ---- TChunkPanel ---- }

constructor TChunkPanel.Create(AOwnerForm: TProjectEditWindow;
  ASourceParent, ATransParent: TScrollBox;
  const ASourceText, ATransText, AChapterID, AChunkName, AVerseLabel: string;
  AStartVerse, AEndVerse: Integer; AFinished: Boolean; AProject: TProject);
var
  PanelHeight, SourceH, TransH: Integer;
  HeaderHeight, FooterHeight, BodyTop: Integer;
  HeaderLabel: TLabel;
begin
  inherited Create;
  FOwnerForm := AOwnerForm;
  FChapterID := AChapterID;
  FChunkName := AChunkName;
  FProject := AProject;
  FEditing := False;
  FTransText := ATransText;
  FStartVerse := AStartVerse;
  FEndVerse := AEndVerse;
  HeaderHeight := 28;
  FooterHeight := 34;
  BodyTop := HeaderHeight + 2;

  { Source panel — alTop stacks by Top value, so set high to append at bottom }
  FSourcePanel := TPanel.Create(ASourceParent);
  FSourcePanel.Parent := ASourceParent;
  FSourcePanel.Top := ASourceParent.ControlCount * 100;
  FSourcePanel.Align := alTop;
  FSourcePanel.BorderSpacing.Bottom := 10;
  FSourcePanel.BevelOuter := bvLowered;
  FSourcePanel.Color := clWhite;

  { Chunk header label }
  HeaderLabel := TLabel.Create(FSourcePanel);
  HeaderLabel.Parent := FSourcePanel;
  HeaderLabel.Left := 10;
  HeaderLabel.Top := 6;
  HeaderLabel.Caption := AVerseLabel;
  HeaderLabel.Font.Height := -11;
  HeaderLabel.Font.Style := [fsBold];
  HeaderLabel.Font.Color := $8A8A8A;
  HeaderLabel.OnClick := @AOwnerForm.OnChunkPanelClick;

  { Source verse display }
  FSourceDisplay := TVerseDisplay.Create(FSourcePanel);
  FSourceDisplay.Parent := FSourcePanel;
  FSourceDisplay.Left := 8;
  FSourceDisplay.Top := BodyTop;
  FSourceDisplay.Width := ASourceParent.ClientWidth - 16;
  FSourceDisplay.Color := clWhite;
  FSourceDisplay.Font.Name := 'Roboto';
  FSourceDisplay.Font.Height := -13;
  FSourceDisplay.BadgeColor := $00B5652D;
  FSourceDisplay.Text := ASourceText;
  FSourceDisplay.OnClick := @AOwnerForm.OnChunkPanelClick;
  FSourcePanel.OnClick := @AOwnerForm.OnChunkPanelClick;

  { Calculate source height — use parent width since Align hasn't been applied yet }
  SourceH := FSourceDisplay.CalcNeededHeight(ASourceParent.ClientWidth - 16) + BodyTop + 8;
  if SourceH < 50 then
    SourceH := 50;
  FSourceDisplay.Height := SourceH - BodyTop - 8;
  FSourcePanel.Height := SourceH;

  { Translation panel — alTop stacks by Top value, so set high to append at bottom }
  FTransPanel := TPanel.Create(ATransParent);
  FTransPanel.Parent := ATransParent;
  FTransPanel.Top := ATransParent.ControlCount * 100;
  FTransPanel.Align := alTop;
  FTransPanel.BorderSpacing.Bottom := 10;
  FTransPanel.BevelOuter := bvLowered;
  FTransPanel.Color := clWhite;

  { Translation verse display (read-only view) }
  FTransDisplay := TVerseDisplay.Create(FTransPanel);
  FTransDisplay.Parent := FTransPanel;
  FTransDisplay.Left := 8;
  FTransDisplay.Top := BodyTop;
  FTransDisplay.Width := ATransParent.ClientWidth - 16;
  FTransDisplay.Color := clWhite;
  FTransDisplay.Font.Name := 'Roboto';
  FTransDisplay.Font.Height := -13;
  FTransDisplay.BadgeColor := $009A8A00;
  if ATransText <> '' then
    FTransDisplay.Text := ATransText
  else
  begin
    FTransDisplay.Text := '';
    FTransDisplay.Font.Color := clGray;
  end;
  FTransDisplay.OnClick := @AOwnerForm.OnChunkPanelClick;
  FTransPanel.OnClick := @AOwnerForm.OnChunkPanelClick;

  { Calculate translation height — use parent width since Align hasn't been applied yet }
  if ATransText <> '' then
    TransH := FTransDisplay.CalcNeededHeight(ATransParent.ClientWidth - 16)
  else
    TransH := 30;
  if TransH < 30 then
    TransH := 30;
  FTransDisplay.Height := TransH;

  { Use the taller of source/trans for both panels }
  PanelHeight := SourceH;
  if TransH + BodyTop + FooterHeight + 4 > PanelHeight then
    PanelHeight := TransH + BodyTop + FooterHeight + 4;
  FSourcePanel.Height := PanelHeight;
  FSourceDisplay.Height := PanelHeight - BodyTop - 8;
  FTransPanel.Height := PanelHeight;
  FTransDisplay.Height := PanelHeight - BodyTop - FooterHeight - 6;

  { Edit memo (hidden initially) }
  FTransMemo := TMemo.Create(FTransPanel);
  FTransMemo.Parent := FTransPanel;
  FTransMemo.Left := 8;
  FTransMemo.Top := BodyTop;
  FTransMemo.Width := FTransPanel.Width - 16;
  FTransMemo.Height := PanelHeight - BodyTop - FooterHeight - 6;
  FTransMemo.Anchors := [akTop, akLeft, akBottom];
  FTransMemo.Text := ATransText;
  FTransMemo.Font.Name := 'Roboto';
  FTransMemo.Font.Height := -13;
  FTransMemo.ScrollBars := ssAutoVertical;
  FTransMemo.Visible := False;
  FTransMemo.OnExit := @AOwnerForm.OnChunkMemoExit;
  FTransMemo.OnClick := @AOwnerForm.OnChunkPanelClick;

  { Edit button }
  FEditButton := TButton.Create(FTransPanel);
  FEditButton.Parent := FTransPanel;
  FEditButton.Width := 32;
  FEditButton.Height := 24;
  FEditButton.Left := FTransPanel.Width - 42;
  FEditButton.Top := 4;
  FEditButton.Anchors := [akTop, akRight];
  FEditButton.Caption := #9998;
  FEditButton.Font.Style := [fsBold];
  FEditButton.OnClick := @AOwnerForm.OnChunkEditClick;

  { Hidden checkbox stores finished state and manifest wiring }
  FFinishedCheck := TCheckBox.Create(FTransPanel);
  FFinishedCheck.Parent := FTransPanel;
  FFinishedCheck.Visible := False;
  FFinishedCheck.Checked := AFinished;
  FFinishedCheck.Hint := AChapterID;
  FFinishedCheck.HelpKeyword := AChunkName;
  FFinishedCheck.OnChange := @AOwnerForm.OnChunkFinishedChange;

  { Footer label and slider-like toggle }
  FFinishedLabel := TLabel.Create(FTransPanel);
  FFinishedLabel.Parent := FTransPanel;
  FFinishedLabel.Left := 10;
  FFinishedLabel.Top := PanelHeight - FooterHeight + 8;
  FFinishedLabel.Caption := rsFinishedToggleLabel;
  FFinishedLabel.Font.Color := $00909090;
  FFinishedLabel.Anchors := [akLeft, akBottom];

  FFinishedTrack := TShape.Create(FTransPanel);
  FFinishedTrack.Parent := FTransPanel;
  FFinishedTrack.Shape := stRoundRect;
  FFinishedTrack.Width := 38;
  FFinishedTrack.Height := 18;
  FFinishedTrack.Left := FTransPanel.Width - 52;
  FFinishedTrack.Top := PanelHeight - FooterHeight + 8;
  FFinishedTrack.Anchors := [akRight, akBottom];
  FFinishedTrack.Pen.Color := $00C8C8C8;

  FFinishedKnob := TShape.Create(FTransPanel);
  FFinishedKnob.Parent := FTransPanel;
  FFinishedKnob.Shape := stCircle;
  FFinishedKnob.Width := 14;
  FFinishedKnob.Height := 14;
  FFinishedKnob.Top := FFinishedTrack.Top + 2;
  FFinishedKnob.Anchors := [akRight, akBottom];
  FFinishedKnob.Pen.Color := clWhite;
  FFinishedKnob.Brush.Color := clWhite;

  FFinishedToggleBtn := TSpeedButton.Create(FTransPanel);
  FFinishedToggleBtn.Parent := FTransPanel;
  FFinishedToggleBtn.Left := FFinishedTrack.Left - 2;
  FFinishedToggleBtn.Top := FFinishedTrack.Top - 2;
  FFinishedToggleBtn.Width := FFinishedTrack.Width + 4;
  FFinishedToggleBtn.Height := FFinishedTrack.Height + 4;
  FFinishedToggleBtn.Caption := '';
  FFinishedToggleBtn.Flat := True;
  FFinishedToggleBtn.Transparent := True;
  FFinishedToggleBtn.Anchors := [akRight, akBottom];
  FFinishedToggleBtn.OnClick := @AOwnerForm.OnChunkFinishedToggleClick;

  UpdateFinishedVisuals;

  { If finished, disable editing and use green text }
  if AFinished then
  begin
    FEditButton.Enabled := False;
    FTransDisplay.Font.Color := clGreen;
    FTransDisplay.Invalidate;
  end;

  SetSelected(False);
end;

destructor TChunkPanel.Destroy;
begin
  FreeAndNil(FSourcePanel);
  FreeAndNil(FTransPanel);
  inherited Destroy;
end;

procedure TChunkPanel.RecalcLayout;
var
  SourceW, TransW, SourceH, TransH, PanelHeight: Integer;
  HeaderHeight, FooterHeight, BodyTop: Integer;
begin
  HeaderHeight := 28;
  FooterHeight := 34;
  BodyTop := HeaderHeight + 2;

  { Use panel's current client width for display sizing }
  SourceW := FSourcePanel.ClientWidth - 16;
  TransW := FTransPanel.ClientWidth - 16;
  if SourceW < 40 then SourceW := 40;
  if TransW < 40 then TransW := 40;
  FSourceDisplay.Width := SourceW;
  FTransDisplay.Width := TransW;
  FTransMemo.Width := TransW;

  SourceH := FSourceDisplay.CalcNeededHeight(SourceW) + BodyTop + 8;
  if SourceH < 50 then
    SourceH := 50;

  if FTransDisplay.FRawText <> '' then
    TransH := FTransDisplay.CalcNeededHeight(TransW)
  else
    TransH := 30;
  if TransH < 30 then
    TransH := 30;

  { Use the taller of source/trans for both panels }
  PanelHeight := SourceH;
  if TransH + BodyTop + FooterHeight + 4 > PanelHeight then
    PanelHeight := TransH + BodyTop + FooterHeight + 4;

  FSourcePanel.Height := PanelHeight;
  FSourceDisplay.Height := PanelHeight - BodyTop - 8;
  FTransPanel.Height := PanelHeight;
  FTransDisplay.Height := PanelHeight - BodyTop - FooterHeight - 6;
  FTransMemo.Height := PanelHeight - BodyTop - FooterHeight - 6;

  FSourceDisplay.Invalidate;
  FTransDisplay.Invalidate;
end;

procedure TChunkPanel.SetEditing(AEdit: Boolean);
begin
  if FFinishedCheck.Checked and AEdit then
    Exit;

  FEditing := AEdit;
  FTransDisplay.Visible := not AEdit;
  FTransMemo.Visible := AEdit;

  if AEdit then
  begin
    FTransMemo.Text := FTransText;
    FEditButton.Caption := #10003;
    FTransMemo.Color := $00FFFDF0;
    FTransMemo.SetFocus;
  end
  else
  begin
    SaveContent;
    FEditButton.Caption := #9998;
    FTransDisplay.Color := clWhite;
  end;
end;

procedure TChunkPanel.SaveContent;
begin
  if FEditing then
  begin
    FTransText := FTransMemo.Text;
    FTransDisplay.Text := FTransText;
    if FTransText <> '' then
      FTransDisplay.Font.Color := clBlack
    else
      FTransDisplay.Font.Color := clGray;
  end;
end;

procedure TChunkPanel.UpdateFinishedVisuals;
begin
  if FFinishedCheck.Checked then
  begin
    FFinishedTrack.Brush.Color := $009CC96B;
    FFinishedTrack.Pen.Color := $009CC96B;
    FFinishedKnob.Left := FFinishedTrack.Left + FFinishedTrack.Width - FFinishedKnob.Width - 2;
  end
  else
  begin
    FFinishedTrack.Brush.Color := $00D8D8D8;
    FFinishedTrack.Pen.Color := $00D8D8D8;
    FFinishedKnob.Left := FFinishedTrack.Left + 2;
  end;
end;

procedure TChunkPanel.SetSelected(ASelected: Boolean);
begin
  if ASelected then
  begin
    FSourcePanel.BevelColor := $00B8792F;
    FTransPanel.BevelColor := $00B8792F;
  end
  else
  begin
    FSourcePanel.BevelColor := $00D0D0D0;
    FTransPanel.BevelColor := $00D0D0D0;
  end;
end;

function TChunkPanel.OwnsControl(AObj: TObject): Boolean;
begin
  Result := (AObj = FSourcePanel) or (AObj = FTransPanel) or
            (AObj = FSourceDisplay) or (AObj = FTransDisplay) or
            (AObj = FTransMemo) or (AObj = FFinishedToggleBtn) or
            (AObj = FEditButton);
end;

function TChunkPanel.GetHeight: Integer;
begin
  Result := FSourcePanel.Height;
end;

end.
