unit ProjectEditForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs,
  ExtCtrls, StdCtrls, Buttons, ComCtrls, Types, Menus,
  fpjson, jsonparser, IpHtml,
  ProjectManager, ResourceContainer, ProjectScanner,
  BibleBook, BibleChapter, BibleChunk, USFMUtils, DataPaths, ProjectCreator,
  AppSettings, SettingsForm, ThemePalette, UIFonts, AppLog,
  IndexDatabase, SourceExtractor, LocaleManager;

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
  rsMenuUploadExport = 'Upload/Export';
  rsMenuPrint = 'Print';
  rsMenuSettings = 'Settings';
  rsMenuDevTools = 'Developer Tools';
  rsMenuProjectReview = 'Project Review';
  rsMenuFeedback = 'Feedback';
  rsMenuMarkAllDone = 'Mark All Chunks Done';
  rsExportFilterEdit = 'Translation Studio Package (*.tstudio)|*.tstudio|All files|*.*';
  rsTStudioExtEdit = 'tstudio';
  rsExportFailedEdit = 'Export failed: ';
  rsExportedEdit = 'Exported: ';
  rsNoSource = 'No source';
  rsTranslationClickToView = 'Translation (click to view)';
  rsSourceClickToView = 'Source (click to view)';
  rsClickCardToTranslate = 'Click the card to translate';
  rsClickToViewSource = 'Click here to view source';
  rsChunkVersesFmt = 'Verses %s';
  rsSelectSourceText = 'Select Source Text';
  rsBtnOK = 'OK';
  rsBtnCancel = 'Cancel';
  rsTabNotes = 'Notes';
  rsTabWords = 'Words';
  rsTabQuestions = 'Questions';
  rsCloseBtn = 'X CLOSE';

type
  TResourceTab = (rtNotes, rtWords, rtQuestions);

  TResourceSection = record
    Heading: string;
    Body: string;
  end;
  TResourceSectionArray = array of TResourceSection;

  TViewMode = (vmRead, vmEditReview, vmBlindEdit);

  TChunkPanel = class;

  { TProjectEditWindow }

  TProjectEditWindow = class(TForm)
    btnMenu: TSpeedButton;
    LeftRail: TPanel;
    TopPanel: TPanel;
    lblProjectTitle: TLabel;
    StatusPanel: TPanel;
    lblStatus: TLabel;
    SplitPanel: TPanel;
    PaneHeaderBar: TPanel;
    lblSourceHeader: TLabel;
    SourceLangHeader: TLabel;
    btnChangeSource: TButton;
    lblTransHeader: TLabel;
    lblTransLangHeader: TLabel;
    lblResourceHeader: TLabel;
    Splitter1: TSplitter;
    Splitter2: TSplitter;
    SourcePanel: TPanel;
    SourceScrollBox: TScrollBox;
    TransPanel: TPanel;
    TransScrollBox: TScrollBox;
    ResourcePanel: TPanel;
    ResourceScrollBox: TScrollBox;
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
    { Controls created in code (not in LFM) }
    btnBack: TSpeedButton;
    btnPrevChapter: TSpeedButton;
    lblChapterNum: TLabel;
    btnNextChapter: TSpeedButton;
    cmbChapterJump: TComboBox;
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
    FLayoutDirection: string;
    FSourceLangCode: string;
    FSourceResourceType: string;
    FBookCode: string;
    FSummary: TProjectSummary;
    FChapterDirty: Boolean;
    FLastResourcePos: Integer;

    procedure ClearChunkPanels;
    procedure LoadChapter(AIndex: Integer);
    procedure SaveCurrentChapter;
    procedure UpdateStatus;
    procedure UpdateChapterNav;
    procedure OnChunkFinishedChange(Sender: TObject);
    procedure OnChunkFinishedToggleClick(Sender: TObject);
    procedure OnChunkMemoExit(Sender: TObject);
    procedure OnChunkMemoChange(Sender: TObject);
    procedure OnChunkEditClick(Sender: TObject);
    procedure OnChunkPanelClick(Sender: TObject);
    procedure PaneMouseWheel(Sender: TObject; Shift: TShiftState;
      WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
    procedure ScrollSyncTimerFire(Sender: TObject);
    procedure AttachWheelHandlers(AParent: TWinControl);
    function IsControlInPane(AControl: TControl; APane: TWinControl): Boolean;
    procedure SetSelectedChunkIndex(AIndex: Integer);
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
    procedure RecalcTimerFire(Sender: TObject);
    procedure OnMenuUploadExport(Sender: TObject);
    procedure OnMenuPrint(Sender: TObject);
    procedure OnMenuSettings(Sender: TObject);
    procedure OnMenuDevTools(Sender: TObject);
    procedure OnMenuProjectReview(Sender: TObject);
    procedure OnMenuFeedback(Sender: TObject);
    procedure OnMenuMarkAllDone(Sender: TObject);
  private
    FRecalcTimer: TTimer;
    FSourceProportion: Double;
    FResourceProportion: Double;
    FEditMenu: TPopupMenu;
  private
    { Left rail controls (created in code, not LFM) }
    FCurrentViewMode: TViewMode;
    btnHamburger: TSpeedButton;
    btnModeRead: TSpeedButton;
    btnModeBlindEdit: TSpeedButton;
    btnModeEditReview: TSpeedButton;
    pnlChapterNav: TPanel;
    procedure CreateRailControls;
    procedure UpdateRailLayout;
    procedure UpdateModeButtons;
    procedure btnModeReadClick(Sender: TObject);
    procedure btnModeBlindEditClick(Sender: TObject);
    procedure btnModeEditReviewClick(Sender: TObject);
    procedure cmbChapterJumpChange(Sender: TObject);
    procedure lblChapterNumClick(Sender: TObject);
  private
    { Read mode controls }
    FReadContainer: TPanel;
    FReadCard: TPanel;
    FReadHtml: TIpHtmlPanel;
    FReadSourceLabel: TLabel;
    FReadBackTab: TPanel;
    FReadBackTabLabel: TLabel;
    FReadShowingSource: Boolean;
    procedure CreateReadModeControls;
    procedure ShowReadMode;
    procedure ShowEditReviewMode;
    procedure LayoutReadModeCards;
    procedure LoadReadModeContent;
    procedure ReadBackTabClick(Sender: TObject);
    function BuildFullChapterHtml(const ChapterID: string;
      ASourceChapter: TChapter; IsSource: Boolean): string;
  private
    { Blind Edit mode controls }
    FBlindContainer: TPanel;
    FBlindSourceCard: TPanel;
    FBlindSourceHtml: TIpHtmlPanel;
    FBlindTransCard: TPanel;
    FBlindTransMemo: TMemo;
    FBlindChunkLabel: TLabel;
    FBlindPrevBtn: TSpeedButton;
    FBlindNextBtn: TSpeedButton;
    FBlindFlipLabel: TLabel;
    FBlindShowingSource: Boolean;
    FBlindChunkIndex: Integer;
    FBlindChunkCount: Integer;
    FBlindChunkNames: TStringList;  { chunk names for current chapter }
    FBlindChunkDirty: Boolean;
    procedure CreateBlindEditControls;
    procedure ShowBlindEditMode;
    procedure LayoutBlindEditCards;
    procedure LoadBlindEditChunk;
    procedure SaveBlindEditChunk;
    procedure BlindCardClick(Sender: TObject);
    procedure BlindPrevClick(Sender: TObject);
    procedure BlindNextClick(Sender: TObject);
    procedure BlindMemoChange(Sender: TObject);
    { Verse-range helpers for blind edit (bypass \v marker scanning) }
    function GetSourceChunkVerse(ASourceChapter: TChapter; ChunkIndex: Integer): Integer;
    function LoadBlindChunkText(ASourceChapter: TChapter; ChunkIndex: Integer): string;
    procedure WriteBlindChunkToProject(ASourceChapter: TChapter; ChunkIndex: Integer;
      const TransText: string);
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
    FResourcePanel: TPanel;
    FSourceHtml: TIpHtmlPanel;
    FTransHtml: TIpHtmlPanel;
    FResHtml: TIpHtmlPanel;
    FResTabBar: TPanel;
    FBtnTabNotes: TButton;
    FBtnTabWords: TButton;
    FBtnTabQuestions: TButton;
    FSourceText: string;   { raw USFM text for source chunk }
    FTransText: string;    { raw USFM text for this chunk }
    FSourceBadgeColor: TColor;
    FTransBadgeColor: TColor;
    FIsFinished: Boolean;
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
    FActiveResTab: TResourceTab;
    FResourceSections: TResourceSectionArray;
    procedure RefreshSourceHtml;
    procedure RefreshTransHtml;
    procedure OnResTabClick(Sender: TObject);
    procedure OnResHotClick(Sender: TObject);
  public
    constructor Create(AOwnerForm: TProjectEditWindow;
      ASourceParent, ATransParent, AResourceParent: TScrollBox;
      const ASourceText, ATransText, AChapterID, AChunkName, AVerseLabel: string;
      AStartVerse, AEndVerse: Integer;
      AFinished: Boolean; AProject: TProject);
    destructor Destroy; override;
    procedure SetEditing(AEdit: Boolean);
    procedure SaveContent;
    procedure RecalcLayout;
    procedure ForceHtmlRelayout;
    procedure LoadResources;
    procedure UpdateFinishedVisuals;
    procedure SetSelected(ASelected: Boolean);
    function OwnsControl(AObj: TObject): Boolean;
    function GetHeight: Integer;
    property StartVerse: Integer read FStartVerse;
    property EndVerse: Integer read FEndVerse;
    property SourcePanel: TPanel read FSourcePanel;
    property TransPanel: TPanel read FTransPanel;
    property ResourcePanel: TPanel read FResourcePanel;
  end;

var
  ProjectEditWindow: TProjectEditWindow;

implementation

uses
  MainForm, ImportForm, TStudioPackage, USFMExporter,
  UserProfile, GiteaClient, GitUtils, ConflictResolver, DevToolsForm;

{$R *.lfm}

{ Strip all USFM backslash markers from text, returning clean prose.
  Removes \v N, \p, \s5, \q, \d, \f+...\f*, etc. and their trailing spaces.
  Verse numbers after \v are also removed. }
function StripUSFMMarkersFromText(const S: string): string;
var
  I, Len: Integer;
begin
  Result := '';
  I := 1;
  Len := Length(S);
  while I <= Len do
  begin
    if (S[I] = '\') and (I + 1 <= Len) and
       (S[I + 1] in ['a'..'z', 'A'..'Z', '*']) then
    begin
      Inc(I);  { skip backslash }
      { Skip marker word: letters, digits, *, + }
      while (I <= Len) and (S[I] in ['a'..'z', 'A'..'Z', '0'..'9', '*', '+']) do
        Inc(I);
      { Skip space between marker and its argument }
      if (I <= Len) and (S[I] = ' ') then Inc(I);
      { If next chars are digits (verse/chapter number), skip them too }
      if (I <= Len) and (S[I] in ['0'..'9']) then
      begin
        while (I <= Len) and (S[I] in ['0'..'9']) do Inc(I);
        { Skip space after number }
        if (I <= Len) and (S[I] = ' ') then Inc(I);
      end;
    end
    else
    begin
      Result := Result + S[I];
      Inc(I);
    end;
  end;
  Result := Trim(Result);
end;

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

{ Delete only chunk files in Dir whose base name (without Ext) is not in
  Keep. Used at save time to retire chunks that disappear under a new
  chunking, while leaving still-current chunk files alone so per-file
  dirty tracking can decide whether to rewrite them. }
procedure RemoveStaleChunkFiles(const Dir, Ext: string; Keep: TStringList);
var
  SR: TSearchRec;
  FullDir, BaseName: string;
begin
  FullDir := IncludeTrailingPathDelimiter(Dir);
  if FindFirst(FullDir + '*' + Ext, faAnyFile, SR) = 0 then
  begin
    repeat
      if (SR.Attr and faDirectory) = 0 then
      begin
        BaseName := ChangeFileExt(SR.Name, '');
        if Keep.IndexOf(BaseName) < 0 then
          DeleteFile(FullDir + SR.Name);
      end;
    until FindNext(SR) <> 0;
    FindClose(SR);
  end;
end;

{ ---- USFM to HTML conversion ---- }

function HtmlEscape(const S: string): string;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to Length(S) do
    case S[I] of
      '<': Result := Result + '&lt;';
      '>': Result := Result + '&gt;';
      '&': Result := Result + '&amp;';
      '"': Result := Result + '&quot;';
    else
      Result := Result + S[I];
    end;
end;

function ColorToHtmlHex(C: TColor): string;
{ Convert BGR TColor to #RRGGBB }
var
  R, G, B: Byte;
begin
  C := ColorToRGB(C);
  R := C and $FF;
  G := (C shr 8) and $FF;
  B := (C shr 16) and $FF;
  Result := '#' + IntToHex(R, 2) + IntToHex(G, 2) + IntToHex(B, 2);
end;

function SkipMarkerName(const S: string; P: Integer): Integer;
{ Advance past a USFM marker name and optional trailing space.
  P should point to the character after the backslash. }
begin
  Result := P;
  while (Result <= Length(S)) and not (S[Result] in [' ', #9, #10, #13, '\']) do
    Inc(Result);
  if (Result <= Length(S)) and (S[Result] = ' ') then
    Inc(Result);
end;

function USFMToHtml(const AText: string; ABadgeColor: TColor;
  const ATextColor: string): string;
{ Convert USFM text to HTML with styled verse badges, poetry indentation,
  Selah, footnotes, section headings, and blank lines. }
var
  S: string;
  P, Start, EndP, Level: Integer;
  SegText, BadgeHex, MarkerName: string;
const
  FootnoteChar = '&#8224;'; { dagger U+2020 }

  function PeekMarkerName: string;
  { Extract the marker name starting at P (which points to the backslash). }
  var
    Q: Integer;
  begin
    Q := P + 1;
    while (Q <= Length(S)) and not (S[Q] in [' ', #9, #10, #13, '\', '*']) do
      Inc(Q);
    Result := Copy(S, P + 1, Q - P - 1);
  end;

  procedure SkipToEndOfLine;
  begin
    while (P <= Length(S)) and not (S[P] in [#10, #13]) do
      Inc(P);
    if (P <= Length(S)) and (S[P] = #13) then Inc(P);
    if (P <= Length(S)) and (S[P] = #10) then Inc(P);
  end;

  function ReadToEndOfLine: string;
  begin
    Start := P;
    while (P <= Length(S)) and not (S[P] in [#10, #13, '\']) do
      Inc(P);
    Result := Trim(Copy(S, Start, P - Start));
    if (P <= Length(S)) and (S[P] in [#10, #13]) then
    begin
      if (P <= Length(S)) and (S[P] = #13) then Inc(P);
      if (P <= Length(S)) and (S[P] = #10) then Inc(P);
    end;
  end;

begin
  Result := '';
  S := AText;
  if S = '' then Exit;

  BadgeHex := ColorToHtmlHex(ABadgeColor);

  P := 1;
  while P <= Length(S) do
  begin
    if S[P] <> '\' then
    begin
      { Plain text }
      Start := P;
      while (P <= Length(S)) and (S[P] <> '\') do
        Inc(P);
      SegText := Copy(S, Start, P - Start);
      if Trim(SegText) <> '' then
        Result := Result + '<span style="color:' + ATextColor + ';">' +
          HtmlEscape(SegText) + '</span>';
    end
    else
    begin
      MarkerName := PeekMarkerName;

      if MarkerName = 'v' then
      begin
        P := P + 3; { skip \v and space }
        Start := P;
        while (P <= Length(S)) and (S[P] in ['0'..'9', '-']) do
          Inc(P);
        SegText := Copy(S, Start, P - Start);
        Result := Result + ' <span style="background-color:' + BadgeHex +
          '; color:white; padding:1px 5px; font-weight:bold;' +
          ' font-size:80%;">' + HtmlEscape(SegText) + '</span> ';
        while (P <= Length(S)) and (S[P] in [' ', #9, #10, #13]) do
          Inc(P);
      end
      else if MarkerName = 'f' then
      begin
        { Skip entire footnote content until \f* }
        EndP := Pos('\f*', S, P);
        if EndP > 0 then
          P := EndP + 3
        else
          P := Length(S) + 1;
        Result := Result + ' <span style="background-color:#FF8040; color:white;' +
          ' padding:1px 3px; font-weight:bold; font-size:80%;">' +
          FootnoteChar + '</span> ';
      end
      else if MarkerName = 'x' then
      begin
        { Skip cross-reference until \x* }
        EndP := Pos('\x*', S, P);
        if EndP > 0 then
          P := EndP + 3
        else
          P := Length(S) + 1;
      end
      else if MarkerName = 'b' then
      begin
        { Blank line / stanza break }
        P := P + 2; { skip \b }
        if (P <= Length(S)) and (S[P] = ' ') then Inc(P);
        Result := Result + '<p style="margin:0.3em 0;">&nbsp;</p>';
        if (P <= Length(S)) and (S[P] in [#10, #13]) then SkipToEndOfLine;
      end
      else if MarkerName = 'd' then
      begin
        { Descriptive title (Psalms) — italic }
        P := P + 2;
        if (P <= Length(S)) and (S[P] = ' ') then Inc(P);
        SegText := ReadToEndOfLine;
        if SegText <> '' then
          Result := Result + '<p style="font-style:italic; color:#606060;' +
            ' margin:0 0 0.3em 0;">' + HtmlEscape(SegText) + '</p>';
      end
      else if MarkerName = 'r' then
      begin
        { Parallel passage reference — italic, muted }
        P := P + 2;
        if (P <= Length(S)) and (S[P] = ' ') then Inc(P);
        SegText := ReadToEndOfLine;
        if SegText <> '' then
          Result := Result + '<p style="font-style:italic; color:#606060;' +
            ' margin:0 0 0.3em 0;">' + HtmlEscape(SegText) + '</p>';
      end
      else if (MarkerName = 's') or (MarkerName = 's1') or
              (MarkerName = 's2') or (MarkerName = 's3') or
              (MarkerName = 's5') then
      begin
        { Section heading }
        P := P + 1 + Length(MarkerName);
        if (P <= Length(S)) and (S[P] = ' ') then Inc(P);
        if MarkerName = 's5' then
        begin
          { unfoldingWord chunk boundary marker — don't render }
          SkipToEndOfLine;
        end
        else
        begin
          SegText := ReadToEndOfLine;
          if SegText <> '' then
            Result := Result + '<p style="font-weight:bold; margin:0.5em 0 0.2em 0;">' +
              HtmlEscape(SegText) + '</p>';
        end;
      end
      else if (MarkerName = 'q') or (MarkerName = 'q1') or
              (MarkerName = 'q2') or (MarkerName = 'q3') or
              (MarkerName = 'q4') then
      begin
        { Poetry indentation }
        P := P + 1 + Length(MarkerName);
        if (P <= Length(S)) and (S[P] = ' ') then Inc(P);
        if MarkerName = 'q3' then Level := 4
        else if MarkerName = 'q4' then Level := 5
        else if MarkerName = 'q2' then Level := 3
        else Level := 2; { q, q1 }
        Result := Result + '<br><span style="margin-left:' +
          IntToStr(Level) + 'em; display:inline-block;"></span>';
      end
      else if MarkerName = 'p' then
      begin
        P := P + 2;
        if (P <= Length(S)) and (S[P] = ' ') then Inc(P);
        Result := Result + '<br>';
      end
      else if MarkerName = 'm' then
      begin
        { Margin/continuation paragraph — no indent }
        P := P + 2;
        if (P <= Length(S)) and (S[P] = ' ') then Inc(P);
        Result := Result + '<br>';
      end
      else if (MarkerName = 'pi') or (MarkerName = 'pi1') then
      begin
        P := P + 1 + Length(MarkerName);
        if (P <= Length(S)) and (S[P] = ' ') then Inc(P);
        Result := Result + '<br><span style="margin-left:2em; display:inline-block;"></span>';
      end
      else if MarkerName = 'nb' then
      begin
        { No-break — suppress paragraph break }
        P := P + 3;
        if (P <= Length(S)) and (S[P] = ' ') then Inc(P);
      end
      else if MarkerName = 'c' then
      begin
        { Chapter marker — skip number }
        P := P + 2;
        if (P <= Length(S)) and (S[P] = ' ') then Inc(P);
        while (P <= Length(S)) and (S[P] in ['0'..'9']) do Inc(P);
        if (P <= Length(S)) and (S[P] = ' ') then Inc(P);
      end
      else if MarkerName = 'qs' then
      begin
        { Selah — italic, visually distinct }
        P := P + 3;
        if (P <= Length(S)) and (S[P] = ' ') then Inc(P);
        Result := Result + '<span style="font-style:italic; color:#606060;">';
      end
      else if MarkerName = 'qs*' then
      begin
        P := P + 4;
        Result := Result + '</span>';
      end
      else if MarkerName = 'tl' then
      begin
        { Transliterated word — italic }
        P := P + 3;
        if (P <= Length(S)) and (S[P] = ' ') then Inc(P);
        Result := Result + '<span style="font-style:italic;">';
      end
      else if MarkerName = 'tl*' then
      begin
        P := P + 4;
        Result := Result + '</span>';
      end
      else if MarkerName = 'nd' then
      begin
        { Name of deity — small caps }
        P := P + 3;
        if (P <= Length(S)) and (S[P] = ' ') then Inc(P);
        Result := Result + '<span style="font-variant:small-caps;">';
      end
      else if MarkerName = 'nd*' then
      begin
        P := P + 4;
        Result := Result + '</span>';
      end
      else if MarkerName = 'wj' then
      begin
        { Words of Jesus — red }
        P := P + 3;
        if (P <= Length(S)) and (S[P] = ' ') then Inc(P);
        Result := Result + '<span style="color:#CC0000;">';
      end
      else if MarkerName = 'wj*' then
      begin
        P := P + 4;
        Result := Result + '</span>';
      end
      else if MarkerName = 'add' then
      begin
        { Translator addition — italic }
        P := P + 4;
        if (P <= Length(S)) and (S[P] = ' ') then Inc(P);
        Result := Result + '<span style="font-style:italic;">';
      end
      else if MarkerName = 'add*' then
      begin
        P := P + 5;
        Result := Result + '</span>';
      end
      else if (Length(MarkerName) > 0) and (MarkerName[Length(MarkerName)] = '*') then
      begin
        { Generic closing marker — emit closing span }
        P := P + 1 + Length(MarkerName);
        Result := Result + '</span>';
      end
      else
      begin
        { Unknown marker — skip it, emit content as text }
        P := P + 1 + Length(MarkerName);
        if (P <= Length(S)) and (S[P] = ' ') then Inc(P);
      end;
    end;
  end;
end;

function WrapInHtmlDoc(const ABody, AFontName: string; AFontSize: Integer;
  ABgColor: TColor; const ADirection: string = 'ltr'): string;
begin
  Result := '<html><head><style>' +
    'body { font-family: ' + AFontName + '; font-size: ' + IntToStr(AFontSize) +
    'pt; margin: 4px; background-color: ' + ColorToHtmlHex(ABgColor) + '; }' +
    '</style></head><body dir="' + ADirection + '">' + ABody + '</body></html>';
end;

{ Process wiki-style links and pass through other content }
function ProcessInlineMarkdown(const S: string): string;
var
  P, Start: Integer;
  LinkPath, LinkText: string;
begin
  Result := '';
  P := 1;
  while P <= Length(S) do
  begin
    if (P <= Length(S) - 3) and (S[P] = '[') and (S[P+1] = '[') then
    begin
      Start := P + 2;
      while (P <= Length(S)) and (S[P] <> ']') do
        Inc(P);
      LinkPath := Copy(S, Start, P - Start);
      if (Length(LinkPath) > 0) and (LinkPath[1] = ':') then
        Delete(LinkPath, 1, 1);
      LinkText := LinkPath;
      while Pos(':', LinkText) > 0 do
        Delete(LinkText, 1, Pos(':', LinkText));
      LinkText := StringReplace(LinkText, '-', ' ', [rfReplaceAll]);
      Result := Result + '<i>' + LinkText + '</i>';
      if (P <= Length(S)) and (S[P] = ']') then Inc(P);
      if (P <= Length(S)) and (S[P] = ']') then Inc(P);
    end
    else
    begin
      Result := Result + S[P];
      Inc(P);
    end;
  end;
end;

{ Extract heading text from a markdown # line, stripping # prefix and trailing colon }
function ExtractHeading(const Line: string): string;
var
  P: Integer;
begin
  Result := Trim(Line);
  P := 1;
  while (P <= Length(Result)) and (Result[P] = '#') do
    Inc(P);
  Result := Trim(Copy(Result, P, MaxInt));
  if (Length(Result) > 0) and (Result[Length(Result)] = ':') then
    SetLength(Result, Length(Result) - 1);
  Result := Trim(Result);
end;

{ Test whether a line is a top-level section heading.
  Only markdown # headings count. HTML <h2> etc. are sub-sections
  within translation words entries and stay as body content. }
function IsHeadingLine(const Trimmed: string): Boolean;
begin
  Result := (Length(Trimmed) >= 2) and (Trimmed[1] = '#') and (Trimmed[2] <> '#');
end;

{ Parse resource text into sections. Each section has a heading and body.
  A heading is a markdown # line or an HTML <hN> line. Content before the
  first heading goes into a section with empty heading. }
function ParseResourceSections(const AText: string): TResourceSectionArray;
var
  Lines: TStringList;
  I, Count: Integer;
  Trimmed: string;
begin
  SetLength(Result, 0);
  Count := 0;
  Lines := TStringList.Create;
  try
    Lines.Text := AText;
    for I := 0 to Lines.Count - 1 do
    begin
      Trimmed := Trim(Lines[I]);
      if Trimmed = '' then
      begin
        if Count > 0 then
          Result[Count - 1].Body := Result[Count - 1].Body + LineEnding;
        Continue;
      end;

      if IsHeadingLine(Trimmed) then
      begin
        Inc(Count);
        SetLength(Result, Count);
        Result[Count - 1].Heading := ExtractHeading(Trimmed);
        Result[Count - 1].Body := '';
      end
      else
      begin
        if Count = 0 then
        begin
          Inc(Count);
          SetLength(Result, Count);
          Result[Count - 1].Heading := '';
          Result[Count - 1].Body := '';
        end;
        if Result[Count - 1].Body <> '' then
          Result[Count - 1].Body := Result[Count - 1].Body + LineEnding;
        Result[Count - 1].Body := Result[Count - 1].Body + Lines[I];
      end;
    end;
  finally
    Lines.Free;
  end;
end;

{ Render the heading list as clickable links for the resource pane }
function ResourceHeadingsToHtml(const Sections: TResourceSectionArray): string;
var
  I: Integer;
  Heading: string;
begin
  Result := '';
  for I := 0 to Length(Sections) - 1 do
  begin
    Heading := Sections[I].Heading;
    if Heading = '' then
      Continue;
    Result := Result + '<p style="margin:8px 0;"><a href="section:' +
      IntToStr(I) + '" style="color:#00897B;text-decoration:none;">' +
      Heading + '</a></p>';
  end;
  if Result = '' then
    Result := '<p style="color:#999;">No resources available.</p>';
end;

{ Convert hybrid markdown/HTML resource body to full HTML for popup display }
function ResourceBodyToHtml(const AText: string): string;
var
  Lines: TStringList;
  I: Integer;
  Trimmed: string;
  InParagraph: Boolean;
begin
  Lines := TStringList.Create;
  try
    Lines.Text := AText;
    Result := '';
    InParagraph := False;

    for I := 0 to Lines.Count - 1 do
    begin
      Trimmed := Trim(Lines[I]);

      if Trimmed = '' then
      begin
        if InParagraph then
        begin
          Result := Result + '</p>';
          InParagraph := False;
        end;
        Continue;
      end;

      { HTML block tags — pass through }
      if (Pos('<h1', Trimmed) = 1) or (Pos('<h2', Trimmed) = 1) or
         (Pos('<h3', Trimmed) = 1) or (Pos('<h4', Trimmed) = 1) or
         (Pos('<p>', Trimmed) = 1) or (Pos('<p ', Trimmed) = 1) or
         (Pos('<ul', Trimmed) = 1) or (Pos('</ul', Trimmed) = 1) or
         (Pos('<ol', Trimmed) = 1) or (Pos('</ol', Trimmed) = 1) or
         (Pos('<li', Trimmed) = 1) or (Pos('</li', Trimmed) = 1) or
         (Pos('<img', Trimmed) = 1) or (Pos('<hr', Trimmed) = 1) or
         (Pos('<br', Trimmed) = 1) or (Pos('<div', Trimmed) = 1) or
         (Pos('</div', Trimmed) = 1) or (Pos('</p>', Trimmed) = 1) or
         (Pos('<strong', Trimmed) = 1) then
      begin
        if InParagraph then
        begin
          Result := Result + '</p>';
          InParagraph := False;
        end;
        Result := Result + ProcessInlineMarkdown(Trimmed);
        Continue;
      end;

      { Regular text }
      if not InParagraph then
      begin
        Result := Result + '<p style="margin:4px 0;">';
        InParagraph := True;
      end
      else
        Result := Result + ' ';
      Result := Result + ProcessInlineMarkdown(Trimmed);
    end;

    if InParagraph then
      Result := Result + '</p>';
  finally
    Lines.Free;
  end;
end;

{ ---- TProjectEditWindow ---- }

procedure TProjectEditWindow.CreateRailControls;
{ Build left sidebar controls in code. Icon captions use Unicode glyphs
  as placeholders. TODO: replace with SVG/PNG image glyphs for a more
  polished look across all platforms. }
var
  RW, Y: Integer;

  function MakeRailButton(AParent: TWinControl; const ACaption: string;
    ATop, AFontHeight: Integer): TSpeedButton;
  begin
    Result := TSpeedButton.Create(Self);
    Result.Parent := AParent;
    Result.Flat := True;
    Result.Caption := ACaption;
    Result.Font.Color := clWhite;
    Result.Font.Height := AFontHeight;
    Result.SetBounds(4, ATop, RW, 36);
  end;

begin
  RW := LeftRail.ClientWidth - 8;
  Y := 4;

  { Home/Back — U+2302 ⌂ }
  btnBack := MakeRailButton(LeftRail, '⌂', Y, -22);
  btnBack.Hint := 'Home';
  btnBack.ShowHint := True;
  btnBack.OnClick := @btnBackClick;
  Inc(Y, 44);

  { View mode buttons — TODO: replace captions with SVG/PNG icon glyphs }
  btnModeRead := MakeRailButton(LeftRail, '⊞', Y, -18);
  btnModeRead.Hint := 'Read';
  btnModeRead.ShowHint := True;
  btnModeRead.GroupIndex := 1;
  btnModeRead.Down := (FCurrentViewMode = vmRead);
  btnModeRead.OnClick := @btnModeReadClick;
  Inc(Y, 38);

  btnModeBlindEdit := MakeRailButton(LeftRail, '⊡', Y, -18);
  btnModeBlindEdit.Hint := 'Blind Draft';
  btnModeBlindEdit.ShowHint := True;
  btnModeBlindEdit.GroupIndex := 1;
  btnModeBlindEdit.Down := (FCurrentViewMode = vmBlindEdit);
  btnModeBlindEdit.OnClick := @btnModeBlindEditClick;
  Inc(Y, 38);

  btnModeEditReview := MakeRailButton(LeftRail, '▥', Y, -18);
  btnModeEditReview.Hint := 'Edit-Review';
  btnModeEditReview.ShowHint := True;
  btnModeEditReview.GroupIndex := 1;
  btnModeEditReview.Down := (FCurrentViewMode = vmEditReview);
  btnModeEditReview.OnClick := @btnModeEditReviewClick;
  Inc(Y, 44);

  { Hamburger menu — U+2261 ≡ }
  btnHamburger := MakeRailButton(LeftRail, '≡', Y, -22);
  btnHamburger.Hint := 'Menu';
  btnHamburger.ShowHint := True;
  btnHamburger.OnClick := @btnMenuClick;

  { Chapter nav group — centered vertically by UpdateRailLayout }
  pnlChapterNav := TPanel.Create(Self);
  pnlChapterNav.Parent := LeftRail;
  pnlChapterNav.Width := RW;
  pnlChapterNav.Height := 140;
  pnlChapterNav.Left := 4;
  pnlChapterNav.BevelOuter := bvNone;
  pnlChapterNav.Color := LeftRail.Color;

  { TODO: replace chevron captions with SVG/PNG icon glyphs }
  btnPrevChapter := TSpeedButton.Create(Self);
  btnPrevChapter.Parent := pnlChapterNav;
  btnPrevChapter.Flat := True;
  btnPrevChapter.Caption := '⊼';
  btnPrevChapter.Font.Color := clWhite;
  btnPrevChapter.Font.Height := -22;
  btnPrevChapter.SetBounds(0, 0, RW, 36);
  btnPrevChapter.OnClick := @btnPrevChapterClick;

  { Chapter number — bordered label + dropdown combo for jumping }
  with TShape.Create(Self) do
  begin
    Parent := pnlChapterNav;
    SetBounds(4, 42, RW - 8, 30);
    Shape := stRectangle;
    Pen.Color := clWhite;
    Brush.Style := bsClear;
    SendToBack;
  end;

  lblChapterNum := TLabel.Create(Self);
  lblChapterNum.Parent := pnlChapterNav;
  lblChapterNum.Alignment := taCenter;
  lblChapterNum.Layout := tlCenter;
  lblChapterNum.AutoSize := False;
  lblChapterNum.SetBounds(4, 42, RW - 8, 30);
  lblChapterNum.Font.Color := clWhite;
  lblChapterNum.Font.Height := -16;
  lblChapterNum.Font.Style := [fsBold];
  lblChapterNum.Caption := '01';
  lblChapterNum.Cursor := crHandPoint;

  { Hidden combo box for chapter jump — shown when label is clicked }
  cmbChapterJump := TComboBox.Create(Self);
  cmbChapterJump.Parent := pnlChapterNav;
  cmbChapterJump.Style := csDropDownList;
  cmbChapterJump.SetBounds(2, 42, RW - 4, 30);
  cmbChapterJump.Visible := False;
  cmbChapterJump.OnChange := @cmbChapterJumpChange;

  { Click label to show dropdown }
  lblChapterNum.OnClick := @lblChapterNumClick;

  btnNextChapter := TSpeedButton.Create(Self);
  btnNextChapter.Parent := pnlChapterNav;
  btnNextChapter.Flat := True;
  btnNextChapter.Caption := '⊻';
  btnNextChapter.Font.Color := clWhite;
  btnNextChapter.Font.Height := -22;
  btnNextChapter.SetBounds(0, 80, RW, 36);
  btnNextChapter.OnClick := @btnNextChapterClick;

  { Three-dot menu at bottom — TODO: replace with SVG/PNG icon glyph }
  btnMenu.SetBounds(4, 0, RW, 36);
  btnMenu.Anchors := [akLeft, akBottom, akRight];
  btnMenu.Top := LeftRail.ClientHeight - 40;
end;

procedure TProjectEditWindow.UpdateRailLayout;
begin
  { Center chapter nav group vertically in the rail }
  if pnlChapterNav <> nil then
  begin
    pnlChapterNav.Left := 4;
    pnlChapterNav.Top := (LeftRail.ClientHeight - pnlChapterNav.Height) div 2;
  end;
end;

procedure TProjectEditWindow.UpdateModeButtons;
begin
  btnModeRead.Down := (FCurrentViewMode = vmRead);
  btnModeBlindEdit.Down := (FCurrentViewMode = vmBlindEdit);
  btnModeEditReview.Down := (FCurrentViewMode = vmEditReview);
end;

procedure TProjectEditWindow.btnModeReadClick(Sender: TObject);
begin
  if FCurrentViewMode = vmRead then
    Exit;
  SaveCurrentChapter;
  FCurrentViewMode := vmRead;
  UpdateModeButtons;
  ShowReadMode;
  UpdateStatus;
end;

procedure TProjectEditWindow.btnModeBlindEditClick(Sender: TObject);
begin
  if FCurrentViewMode = vmBlindEdit then
    Exit;
  SaveCurrentChapter;
  FCurrentViewMode := vmBlindEdit;
  UpdateModeButtons;
  ShowBlindEditMode;
  UpdateStatus;
end;

procedure TProjectEditWindow.btnModeEditReviewClick(Sender: TObject);
begin
  if FCurrentViewMode = vmEditReview then
    Exit;
  FCurrentViewMode := vmEditReview;
  UpdateModeButtons;
  ShowEditReviewMode;
  UpdateStatus;
end;

procedure TProjectEditWindow.CreateReadModeControls;
var
  P: TThemePalette;
begin
  P := GetThemePalette(GetEffectiveTheme);

  { Read mode container — same position as SplitPanel, initially hidden }
  FReadContainer := TPanel.Create(Self);
  FReadContainer.Parent := Self;
  FReadContainer.BevelOuter := bvNone;
  FReadContainer.Color := $00E8E8E8;
  FReadContainer.Visible := False;

  { Source label + change control at top center }
  FReadSourceLabel := TLabel.Create(Self);
  FReadSourceLabel.Parent := FReadContainer;
  FReadSourceLabel.Alignment := taCenter;
  FReadSourceLabel.AutoSize := False;
  FReadSourceLabel.Font.Height := -14;
  FReadSourceLabel.Font.Color := P.TextSecondary;
  FReadSourceLabel.Cursor := crHandPoint;
  FReadSourceLabel.OnClick := @btnChangeSourceClick;
  FReadSourceLabel.Hint := 'Click to change source text';
  FReadSourceLabel.ShowHint := True;

  { Back tab — visible strip behind the main card, clickable to swap }
  FReadBackTab := TPanel.Create(Self);
  FReadBackTab.Parent := FReadContainer;
  FReadBackTab.BevelOuter := bvNone;
  FReadBackTab.Color := $00D8D8D8;
  FReadBackTab.Cursor := crHandPoint;
  FReadBackTab.OnClick := @ReadBackTabClick;

  FReadBackTabLabel := TLabel.Create(Self);
  FReadBackTabLabel.Parent := FReadBackTab;
  FReadBackTabLabel.Alignment := taCenter;
  FReadBackTabLabel.Layout := tlCenter;
  FReadBackTabLabel.AutoSize := False;
  FReadBackTabLabel.Font.Height := -13;
  FReadBackTabLabel.Font.Color := $00606060;
  FReadBackTabLabel.Cursor := crHandPoint;
  FReadBackTabLabel.OnClick := @ReadBackTabClick;

  { Main reading card }
  FReadCard := TPanel.Create(Self);
  FReadCard.Parent := FReadContainer;
  FReadCard.BevelOuter := bvNone;
  FReadCard.Color := clWhite;

  FReadHtml := TIpHtmlPanel.Create(Self);
  FReadHtml.Parent := FReadCard;
  FReadHtml.Align := alClient;
  FReadHtml.DefaultTypeFace := 'Roboto';
  FReadHtml.DefaultFontSize := 14;
  FReadHtml.BgColor := clWhite;
  FReadHtml.BorderStyle := bsNone;

  FReadShowingSource := True;
end;

procedure TProjectEditWindow.LayoutReadModeCards;
var
  CardMargin, TopOffset, CardW, CardH: Integer;
begin
  { Source label at top center }
  FReadSourceLabel.SetBounds(0, 4, FReadContainer.ClientWidth, 24);
  if FSourceRC <> nil then
    FReadSourceLabel.Caption := FSourceRC.LanguageCode + ' ' +
      UpperCase(FSourceRC.ResourceType) + '  ✕'
  else
    FReadSourceLabel.Caption := rsNoSource;

  TopOffset := 32;
  CardMargin := 40;
  CardW := FReadContainer.ClientWidth - (CardMargin * 2);
  CardH := FReadContainer.ClientHeight - TopOffset - 12;
  if CardW < 100 then CardW := 100;
  if CardH < 100 then CardH := 100;

  { Main card — full area minus space for back tab at bottom-right }
  FReadCard.SetBounds(
    CardMargin, TopOffset, CardW - 10, CardH - 30);

  { Back tab — visible strip at bottom-right, offset to peek out }
  FReadBackTab.SetBounds(
    CardMargin + 10, TopOffset + 10, CardW - 10, CardH - 10);
  FReadBackTab.SendToBack;
  if FReadShowingSource then
    FReadBackTabLabel.Caption := '  ' + rsTranslationClickToView
  else
    FReadBackTabLabel.Caption := '  ' + rsSourceClickToView;
  FReadBackTabLabel.SetBounds(0, CardH - 40 - 10, CardW - 10, 30);
  FReadBackTabLabel.Alignment := taLeftJustify;
  FReadCard.BringToFront;
end;

procedure TProjectEditWindow.ShowReadMode;
begin
  SaveBlindEditChunk;
  SplitPanel.Visible := False;
  FBlindContainer.Visible := False;

  FReadContainer.SetBounds(
    SplitPanel.Left, SplitPanel.Top,
    SplitPanel.Width, SplitPanel.Height);
  FReadContainer.Anchors := [akTop, akLeft, akRight, akBottom];

  LayoutReadModeCards;

  FReadContainer.Visible := True;
  FReadShowingSource := True;
  LoadReadModeContent;
end;

procedure TProjectEditWindow.ShowEditReviewMode;
begin
  SaveBlindEditChunk;
  FReadContainer.Visible := False;
  FBlindContainer.Visible := False;
  SplitPanel.Visible := True;
  { Rebuild chunk panels — they weren't created if we were in Read/Blind mode }
  LoadChapter(FCurrentChapterIndex);
end;

procedure TProjectEditWindow.LoadReadModeContent;
var
  SourceChapter: TChapter;
  Html, ChapterID: string;
  Doc: TIpHtml;
  SS: TStringStream;
begin
  if FSourceRC = nil then
    Exit;
  if (FCurrentChapterIndex < 0) or
     (FCurrentChapterIndex >= FSourceRC.Book.Chapters.Count) then
    Exit;

  SourceChapter := FSourceRC.Book.Chapters[FCurrentChapterIndex];
  ChapterID := SourceChapter.ID;

  Html := BuildFullChapterHtml(ChapterID, SourceChapter, FReadShowingSource);

  SS := TStringStream.Create(Html);
  try
    Doc := TIpHtml.Create;
    Doc.LoadFromStream(SS);
    FReadHtml.SetHtml(Doc);
  finally
    SS.Free;
  end;

  { Update back tab label }
  if FReadShowingSource then
    FReadBackTabLabel.Caption := rsTranslationClickToView
  else
    FReadBackTabLabel.Caption := rsSourceClickToView;
end;

procedure TProjectEditWindow.ReadBackTabClick(Sender: TObject);
begin
  FReadShowingSource := not FReadShowingSource;
  LoadReadModeContent;
end;

function TProjectEditWindow.BuildFullChapterHtml(const ChapterID: string;
  ASourceChapter: TChapter; IsSource: Boolean): string;
var
  I: Integer;
  BookName, Body, Dir: string;
  ProjChapter: TChapter;
  MergedText: string;
begin
  BookName := CanonicalBookName(FBookCode);
  if BookName = '' then
    BookName := FBookCode;

  { Determine text direction for this content }
  if IsSource then
    Dir := FSourceRC.Direction
  else
    Dir := FLayoutDirection;

  Result := '<html><body dir="' + Dir + '" style="font-family:Roboto,sans-serif;' +
    'padding:20px 40px;line-height:1.6;">';
  Result := Result + '<h2 style="text-align:center;color:#333;' +
    'font-weight:normal;margin-bottom:20px;">' +
    UpperCase(BookName) + ' ' + ChapterID + '</h2>';

  if IsSource then
  begin
    { Render all source chunks as continuous text }
    for I := 0 to ASourceChapter.Chunks.Count - 1 do
    begin
      Body := UsxToHtml(ASourceChapter.Chunks[I].Content, '#5C6BC0');
      if Body <> '' then
        Result := Result + Body;
    end;
  end
  else
  begin
    { Render merged translation text }
    ProjChapter := nil;
    if (FProject <> nil) and (FProject.Book <> nil) then
      ProjChapter := FProject.Book.GetChapter(ChapterID);
    if ProjChapter <> nil then
    begin
      MergedText := ProjChapter.MergeAllContent;
      { Translation is USFM — render verse markers as superscript numbers }
      Result := Result + '<p style="margin:0;text-indent:1em;">';
      Result := Result + RenderUSFMAsHtml(MergedText);
      Result := Result + '</p>';
    end
    else
      Result := Result + '<p style="color:#999;text-align:center;">' +
        'No translation yet</p>';
  end;

  Result := Result + '</body></html>';
end;

{ ---- Blind Edit Mode ---- }

procedure TProjectEditWindow.CreateBlindEditControls;
var
  P: TThemePalette;
begin
  P := GetThemePalette(GetEffectiveTheme);

  FBlindChunkNames := TStringList.Create;
  FBlindChunkIndex := 0;
  FBlindChunkCount := 0;
  FBlindShowingSource := True;
  FBlindChunkDirty := False;

  { Container — same area as SplitPanel, initially hidden }
  FBlindContainer := TPanel.Create(Self);
  FBlindContainer.Parent := Self;
  FBlindContainer.BevelOuter := bvNone;
  FBlindContainer.Color := $00E8E8E8;
  FBlindContainer.Visible := False;

  { Chunk navigation bar at top }
  FBlindPrevBtn := TSpeedButton.Create(Self);
  FBlindPrevBtn.Parent := FBlindContainer;
  FBlindPrevBtn.Caption := '<';
  FBlindPrevBtn.Flat := True;
  FBlindPrevBtn.Font.Height := -18;
  FBlindPrevBtn.OnClick := @BlindPrevClick;

  FBlindNextBtn := TSpeedButton.Create(Self);
  FBlindNextBtn.Parent := FBlindContainer;
  FBlindNextBtn.Caption := '>';
  FBlindNextBtn.Flat := True;
  FBlindNextBtn.Font.Height := -18;
  FBlindNextBtn.OnClick := @BlindNextClick;

  FBlindChunkLabel := TLabel.Create(Self);
  FBlindChunkLabel.Parent := FBlindContainer;
  FBlindChunkLabel.Alignment := taCenter;
  FBlindChunkLabel.AutoSize := False;
  FBlindChunkLabel.Font.Height := -14;
  FBlindChunkLabel.Font.Color := P.TextSecondary;

  { Source card — front, read-only HTML }
  FBlindSourceCard := TPanel.Create(Self);
  FBlindSourceCard.Parent := FBlindContainer;
  FBlindSourceCard.BevelOuter := bvNone;
  FBlindSourceCard.Color := clWhite;
  FBlindSourceCard.Cursor := crHandPoint;
  FBlindSourceCard.OnClick := @BlindCardClick;

  FBlindSourceHtml := TIpHtmlPanel.Create(Self);
  FBlindSourceHtml.Parent := FBlindSourceCard;
  FBlindSourceHtml.Align := alClient;
  FBlindSourceHtml.DefaultTypeFace := 'Roboto';
  FBlindSourceHtml.DefaultFontSize := 14;
  FBlindSourceHtml.BgColor := clWhite;
  FBlindSourceHtml.BorderStyle := bsNone;

  { Translation card — back, editable memo }
  FBlindTransCard := TPanel.Create(Self);
  FBlindTransCard.Parent := FBlindContainer;
  FBlindTransCard.BevelOuter := bvNone;
  FBlindTransCard.Color := clWhite;
  FBlindTransCard.Visible := False;

  FBlindTransMemo := TMemo.Create(Self);
  FBlindTransMemo.Parent := FBlindTransCard;
  FBlindTransMemo.Align := alClient;
  FBlindTransMemo.BorderStyle := bsNone;
  FBlindTransMemo.ScrollBars := ssAutoVertical;
  FBlindTransMemo.Font.Name := 'Roboto';
  FBlindTransMemo.Font.Height := -16;
  FBlindTransMemo.WordWrap := True;
  FBlindTransMemo.OnChange := @BlindMemoChange;

  { Flip instruction label at bottom of container }
  FBlindFlipLabel := TLabel.Create(Self);
  FBlindFlipLabel.Parent := FBlindContainer;
  FBlindFlipLabel.Alignment := taCenter;
  FBlindFlipLabel.AutoSize := False;
  FBlindFlipLabel.Font.Height := -12;
  FBlindFlipLabel.Font.Color := $00808080;
  FBlindFlipLabel.Caption := rsClickCardToTranslate;
  FBlindFlipLabel.Cursor := crHandPoint;
  FBlindFlipLabel.OnClick := @BlindCardClick;
end;

procedure TProjectEditWindow.ShowBlindEditMode;
begin
  SplitPanel.Visible := False;
  FReadContainer.Visible := False;

  FBlindContainer.SetBounds(
    SplitPanel.Left, SplitPanel.Top,
    SplitPanel.Width, SplitPanel.Height);
  FBlindContainer.Anchors := [akTop, akLeft, akRight, akBottom];

  { Build chunk list for current chapter }
  FBlindChunkNames.Clear;
  FBlindChunkIndex := 0;
  FBlindChunkCount := 0;
  FBlindShowingSource := True;
  FBlindChunkDirty := False;

  if (FSourceRC <> nil) and
     (FCurrentChapterIndex >= 0) and
     (FCurrentChapterIndex < FSourceRC.Book.Chapters.Count) then
  begin
    FBlindChunkCount := FSourceRC.Book.Chapters[FCurrentChapterIndex].Chunks.Count;
    { Skip 'front' title chunk — start on first content chunk if possible }
    if (FBlindChunkCount > 1) and
       (FSourceRC.Book.Chapters[FCurrentChapterIndex].Chunks[0].Name = 'title') then
      FBlindChunkIndex := 1;
  end;

  LayoutBlindEditCards;
  FBlindContainer.Visible := True;
  LoadBlindEditChunk;
end;

procedure TProjectEditWindow.LayoutBlindEditCards;
var
  CardMargin, TopOffset, CardW, CardH, NavH: Integer;
begin
  NavH := 32;
  TopOffset := NavH + 4;
  CardMargin := 40;
  CardW := FBlindContainer.ClientWidth - (CardMargin * 2);
  CardH := FBlindContainer.ClientHeight - TopOffset - 36;
  if CardW < 100 then CardW := 100;
  if CardH < 100 then CardH := 100;

  { Nav bar: prev | chunk label | next }
  FBlindPrevBtn.SetBounds(CardMargin, 4, 32, NavH - 4);
  FBlindNextBtn.SetBounds(FBlindContainer.ClientWidth - CardMargin - 32, 4, 32, NavH - 4);
  FBlindChunkLabel.SetBounds(CardMargin + 36, 4,
    FBlindContainer.ClientWidth - (CardMargin * 2) - 72, NavH - 4);

  { Cards — same position, only one visible at a time }
  FBlindSourceCard.SetBounds(CardMargin, TopOffset, CardW, CardH);
  FBlindTransCard.SetBounds(CardMargin, TopOffset, CardW, CardH);

  { Flip label at bottom }
  FBlindFlipLabel.SetBounds(CardMargin, FBlindContainer.ClientHeight - 28,
    CardW, 24);
end;

procedure TProjectEditWindow.LoadBlindEditChunk;
var
  SourceChapter: TChapter;
  SourceChunk: TChunk;
  ChunkText, Html, Dir, ChunkName: string;
  Doc: TIpHtml;
  SS: TStringStream;
begin
  if FSourceRC = nil then Exit;
  if (FCurrentChapterIndex < 0) or
     (FCurrentChapterIndex >= FSourceRC.Book.Chapters.Count) then Exit;

  SourceChapter := FSourceRC.Book.Chapters[FCurrentChapterIndex];
  FBlindChunkCount := SourceChapter.Chunks.Count;

  if (FBlindChunkIndex < 0) or (FBlindChunkIndex >= FBlindChunkCount) then
    Exit;

  SourceChunk := SourceChapter.Chunks[FBlindChunkIndex];
  ChunkName := SourceChunk.Name;

  { Update nav label }
  if ChunkName = 'title' then
    FBlindChunkLabel.Caption := rsChunkTitle
  else
    FBlindChunkLabel.Caption := Format(rsChunkVersesFmt, [ChunkName]);
  FBlindPrevBtn.Enabled := FBlindChunkIndex > 0;
  FBlindNextBtn.Enabled := FBlindChunkIndex < FBlindChunkCount - 1;

  { Build source HTML for this chunk }
  Dir := FSourceRC.Direction;
  Html := '<html><body dir="' + Dir + '" style="font-family:Roboto,sans-serif;' +
    'padding:20px 30px;line-height:1.6;">';
  Html := Html + UsxToHtml(SourceChunk.Content, '#5C6BC0');
  Html := Html + '</body></html>';

  SS := TStringStream.Create(Html);
  try
    Doc := TIpHtml.Create;
    Doc.LoadFromStream(SS);
    FBlindSourceHtml.SetHtml(Doc);
  finally
    SS.Free;
  end;

  { Load existing translation text for this chunk by verse range (no marker scanning) }
  ChunkText := '';
  if FProject <> nil then
    ChunkText := LoadBlindChunkText(SourceChapter, FBlindChunkIndex);
  { Strip any residual USFM markers that may have come from prior Edit-Review saves }
  ChunkText := StripUSFMMarkersFromText(ChunkText);

  FBlindTransMemo.OnChange := nil;
  FBlindTransMemo.Text := ChunkText;
  FBlindChunkDirty := False;
  FBlindTransMemo.OnChange := @BlindMemoChange;

  { Set memo direction }
  if FLayoutDirection = 'rtl' then
    FBlindTransMemo.BiDiMode := bdRightToLeft
  else
    FBlindTransMemo.BiDiMode := bdLeftToRight;

  { Always start showing source }
  FBlindShowingSource := True;
  FBlindSourceCard.Visible := True;
  FBlindTransCard.Visible := False;
  FBlindFlipLabel.Caption := rsClickCardToTranslate;
end;

procedure TProjectEditWindow.SaveBlindEditChunk;
var
  SourceChapter: TChapter;
  GitErr: string;
begin
  if not FBlindChunkDirty then Exit;
  if FSourceRC = nil then Exit;
  if FProject = nil then Exit;
  if (FCurrentChapterIndex < 0) or
     (FCurrentChapterIndex >= FSourceRC.Book.Chapters.Count) then Exit;

  SourceChapter := FSourceRC.Book.Chapters[FCurrentChapterIndex];
  if (FBlindChunkIndex < 0) or (FBlindChunkIndex >= SourceChapter.Chunks.Count) then
    Exit;

  { Write translator's plain text directly to the ULB chunk file(s) whose
    verse range matches this source chunk. No \v marker scanning required. }
  WriteBlindChunkToProject(SourceChapter, FBlindChunkIndex, FBlindTransMemo.Text);

  CommitProjectChanges(FProject.ProjectDir,
    rsUpdateChapterPrefix + SourceChapter.ID, GitErr);

  FBlindChunkDirty := False;
  LogFmt(llInfo, 'BlindEdit: saved chunk %d of chapter %s',
    [FBlindChunkIndex, SourceChapter.ID]);
end;

{ Returns the starting verse number for a chunk (0 for title / non-numeric). }
function TProjectEditWindow.GetSourceChunkVerse(ASourceChapter: TChapter;
  ChunkIndex: Integer): Integer;
begin
  Result := 0;
  if (ChunkIndex < 0) or (ChunkIndex >= ASourceChapter.Chunks.Count) then Exit;
  TryStrToInt(ASourceChapter.Chunks[ChunkIndex].Name, Result);
end;

{ Load the existing translation text for source chunk ChunkIndex by reading
  English ULB .txt files whose verse range overlaps the source chunk.
  Returns stripped plain text (no USFM markers). }
function TProjectEditWindow.LoadBlindChunkText(ASourceChapter: TChapter;
  ChunkIndex: Integer): string;
var
  SrcStart, SrcEnd, ULBVerse, J: Integer;
  ChapterDir, FilePath, Piece: string;
  ULBBook: TBook;
  ULBChapter: TChapter;
  SL: TStringList;
begin
  Result := '';

  { Title chunk: read front/title.txt }
  if ASourceChapter.Chunks[ChunkIndex].Name = 'title' then
  begin
    FilePath := FProject.ProjectDir + 'front' + PathDelim + 'title.txt';
    if FileExists(FilePath) then
    begin
      SL := TStringList.Create;
      try
        SL.LoadFromFile(FilePath);
        Result := StripUSFMMarkersFromText(SL.Text);
      finally
        SL.Free;
      end;
    end;
    Exit;
  end;

  SrcStart := GetSourceChunkVerse(ASourceChapter, ChunkIndex);
  if ChunkIndex + 1 < ASourceChapter.Chunks.Count then
    SrcEnd := GetSourceChunkVerse(ASourceChapter, ChunkIndex + 1) - 1
  else
    SrcEnd := MaxInt div 2;

  if FEnglishULBContentDir = '' then Exit;

  ULBBook := TBook.Create(FProject.BookCode, 'ulb');
  try
    ULBBook.LoadFromToc(FEnglishULBContentDir);
    ULBChapter := ULBBook.GetChapter(ASourceChapter.ID);
    if ULBChapter = nil then Exit;

    ChapterDir := IncludeTrailingPathDelimiter(
      FProject.ProjectDir + ASourceChapter.ID);

    for J := 0 to ULBChapter.Chunks.Count - 1 do
    begin
      if not TryStrToInt(ULBChapter.Chunks[J].Name, ULBVerse) then Continue;
      if ULBVerse < SrcStart then Continue;
      if ULBVerse > SrcEnd then Break;

      FilePath := ChapterDir + ULBChapter.Chunks[J].Name + '.txt';
      if not FileExists(FilePath) then Continue;

      SL := TStringList.Create;
      try
        SL.LoadFromFile(FilePath);
        Piece := StripUSFMMarkersFromText(SL.Text);
      finally
        SL.Free;
      end;

      if Piece = '' then Continue;
      if Result <> '' then Result := Result + ' ';
      Result := Result + Piece;
    end;
  finally
    ULBBook.Free;
  end;
end;

{ Write the translator's plain text for source chunk ChunkIndex directly to
  the English ULB .txt file(s) covering the same verse range.
  No \v markers are added or required. }
procedure TProjectEditWindow.WriteBlindChunkToProject(ASourceChapter: TChapter;
  ChunkIndex: Integer; const TransText: string);
var
  SrcStart, SrcEnd, ULBVerse, J, PrimaryIdx: Integer;
  ChapterDir, FilePath: string;
  ULBBook: TBook;
  ULBChapter: TChapter;
  SL: TStringList;
begin
  { Title chunk: write to front/title.txt }
  if ASourceChapter.Chunks[ChunkIndex].Name = 'title' then
  begin
    ForceDirectories(FProject.ProjectDir + 'front');
    FilePath := FProject.ProjectDir + 'front' + PathDelim + 'title.txt';
    SL := TStringList.Create;
    try
      SL.Text := TransText;
      SL.SaveToFile(FilePath);
    finally
      SL.Free;
    end;
    Exit;
  end;

  SrcStart := GetSourceChunkVerse(ASourceChapter, ChunkIndex);
  if ChunkIndex + 1 < ASourceChapter.Chunks.Count then
    SrcEnd := GetSourceChunkVerse(ASourceChapter, ChunkIndex + 1) - 1
  else
    SrcEnd := MaxInt div 2;

  { If no English ULB, write to the source chunk's own file name }
  if FEnglishULBContentDir = '' then
  begin
    ChapterDir := IncludeTrailingPathDelimiter(
      FProject.ProjectDir + ASourceChapter.ID);
    ForceDirectories(ChapterDir);
    FilePath := ChapterDir + ASourceChapter.Chunks[ChunkIndex].Name + '.txt';
    SL := TStringList.Create;
    try
      SL.Text := TransText;
      SL.SaveToFile(FilePath);
    finally
      SL.Free;
    end;
    Exit;
  end;

  ULBBook := TBook.Create(FProject.BookCode, 'ulb');
  try
    ULBBook.LoadFromToc(FEnglishULBContentDir);
    ULBChapter := ULBBook.GetChapter(ASourceChapter.ID);
    if ULBChapter = nil then Exit;

    ChapterDir := IncludeTrailingPathDelimiter(
      FProject.ProjectDir + ASourceChapter.ID);
    ForceDirectories(ChapterDir);

    { Find the primary ULB chunk: largest ulbVerse <= SrcStart }
    PrimaryIdx := -1;
    for J := 0 to ULBChapter.Chunks.Count - 1 do
    begin
      if not TryStrToInt(ULBChapter.Chunks[J].Name, ULBVerse) then Continue;
      if ULBVerse <= SrcStart then PrimaryIdx := J;
      if ULBVerse > SrcStart then Break;
    end;

    if PrimaryIdx < 0 then Exit;

    SL := TStringList.Create;
    try
      { Write translator text to primary ULB chunk }
      FilePath := ChapterDir + ULBChapter.Chunks[PrimaryIdx].Name + '.txt';
      SL.Text := TransText;
      SL.SaveToFile(FilePath);

      { Clear any additional ULB chunks within the source chunk's verse range }
      for J := PrimaryIdx + 1 to ULBChapter.Chunks.Count - 1 do
      begin
        if not TryStrToInt(ULBChapter.Chunks[J].Name, ULBVerse) then Continue;
        if ULBVerse > SrcEnd then Break;
        FilePath := ChapterDir + ULBChapter.Chunks[J].Name + '.txt';
        SL.Clear;
        SL.SaveToFile(FilePath);
      end;
    finally
      SL.Free;
    end;
  finally
    ULBBook.Free;
  end;
end;

procedure TProjectEditWindow.BlindCardClick(Sender: TObject);
begin
  if FBlindShowingSource then
  begin
    { Flip to translation side }
    FBlindShowingSource := False;
    FBlindSourceCard.Visible := False;
    FBlindTransCard.Visible := True;
    FBlindFlipLabel.Caption := rsClickToViewSource;
    FBlindTransMemo.SetFocus;
  end
  else
  begin
    { Flip back to source side — save first }
    SaveBlindEditChunk;
    FBlindShowingSource := True;
    FBlindSourceCard.Visible := True;
    FBlindTransCard.Visible := False;
    FBlindFlipLabel.Caption := rsClickCardToTranslate;
  end;
end;

procedure TProjectEditWindow.BlindPrevClick(Sender: TObject);
begin
  if FBlindChunkIndex <= 0 then Exit;
  SaveBlindEditChunk;
  Dec(FBlindChunkIndex);
  LoadBlindEditChunk;
end;

procedure TProjectEditWindow.BlindNextClick(Sender: TObject);
begin
  if FBlindChunkIndex >= FBlindChunkCount - 1 then Exit;
  SaveBlindEditChunk;
  Inc(FBlindChunkIndex);
  LoadBlindEditChunk;
end;

procedure TProjectEditWindow.BlindMemoChange(Sender: TObject);
begin
  FBlindChunkDirty := True;
end;

procedure TProjectEditWindow.lblChapterNumClick(Sender: TObject);
var
  I: Integer;
begin
  if FSourceRC = nil then
    Exit;
  { Populate combo with chapter IDs }
  cmbChapterJump.Items.Clear;
  for I := 0 to FSourceRC.Book.Chapters.Count - 1 do
    cmbChapterJump.Items.Add(FSourceRC.Book.Chapters[I].ID);
  if (FCurrentChapterIndex >= 0) and
     (FCurrentChapterIndex < cmbChapterJump.Items.Count) then
    cmbChapterJump.ItemIndex := FCurrentChapterIndex;
  { Show the combo in place of the label }
  lblChapterNum.Visible := False;
  cmbChapterJump.Visible := True;
  cmbChapterJump.DroppedDown := True;
  cmbChapterJump.SetFocus;
end;

procedure TProjectEditWindow.cmbChapterJumpChange(Sender: TObject);
var
  NewIndex: Integer;
begin
  NewIndex := cmbChapterJump.ItemIndex;
  { Hide combo, show label again }
  cmbChapterJump.Visible := False;
  lblChapterNum.Visible := True;
  if (NewIndex >= 0) and (NewIndex <> FCurrentChapterIndex) then
  begin
    SaveCurrentChapter;
    LoadChapter(NewIndex);
  end;
end;

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
  FLayoutDirection := 'ltr';
  FLastResourcePos := 0;
  if GetBlindEditMode then
    FCurrentViewMode := vmBlindEdit
  else
    FCurrentViewMode := vmEditReview;
  ApplyFontRecursive(Self, 'Noto Sans');
  CreateRailControls;
  CreateReadModeControls;
  CreateBlindEditControls;
  btnMenu.OnClick := @btnMenuClick;

  SourceScrollBox.VertScrollBar.Smooth := True;
  TransScrollBox.VertScrollBar.Smooth := True;
  ResourceScrollBox.VertScrollBar.Smooth := True;

  SourceScrollBox.OnMouseWheel := @PaneMouseWheel;
  TransScrollBox.OnMouseWheel := @PaneMouseWheel;
  ResourceScrollBox.OnMouseWheel := @PaneMouseWheel;
  btnChangeSource.OnClick := @btnChangeSourceClick;
  Splitter1.OnMoved := @SplitterMoved;
  Splitter2.OnMoved := @SplitterMoved;

  FScrollSyncTimer := TTimer.Create(Self);
  FScrollSyncTimer.Interval := 30;
  FScrollSyncTimer.OnTimer := @ScrollSyncTimerFire;
  FScrollSyncTimer.Enabled := True;

  FRecalcTimer := TTimer.Create(Self);
  FRecalcTimer.Interval := 100;
  FRecalcTimer.OnTimer := @RecalcTimerFire;
  FRecalcTimer.Enabled := False;

  { Default proportional split: source 35%, resource 25%, trans fills rest }
  FSourceProportion := 0.35;
  FResourceProportion := 0.25;

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

procedure TProjectEditWindow.RecalcTimerFire(Sender: TObject);
var
  I: Integer;
begin
  FRecalcTimer.Enabled := False;
  { Re-render HTML at final panel widths so GetContentSize is accurate }
  for I := 0 to Length(FChunkPanels) - 1 do
    FChunkPanels[I].ForceHtmlRelayout;
  RecalcAllChunkLayouts;
end;

procedure TProjectEditWindow.FormResize(Sender: TObject);
var
  TotalW, SrcW, ResW: Integer;
begin
  ApplyOrientationLayout(FLayoutDirection);
  UpdatePaneHeaders;

  { Restore proportional panel widths }
  TotalW := SplitPanel.ClientWidth - Splitter1.Width - Splitter2.Width;
  if TotalW > 100 then
  begin
    SrcW := Round(TotalW * FSourceProportion);
    ResW := Round(TotalW * FResourceProportion);
    if SrcW < 100 then SrcW := 100;
    if ResW < 100 then ResW := 100;
    SourcePanel.Width := SrcW;
    ResourcePanel.Width := ResW;
  end;

  UpdateRailLayout;
  RecalcAllChunkLayouts;

  { Re-layout Read/Blind mode cards when visible }
  if (FCurrentViewMode = vmRead) and FReadContainer.Visible then
    LayoutReadModeCards;
  if (FCurrentViewMode = vmBlindEdit) and FBlindContainer.Visible then
    LayoutBlindEditCards;
end;

procedure TProjectEditWindow.SplitterMoved(Sender: TObject);
var
  TotalW: Integer;
begin
  { Store new proportions after user drags a splitter }
  TotalW := SourcePanel.Width + ResourcePanel.Width +
    (SplitPanel.ClientWidth - SourcePanel.Width - ResourcePanel.Width -
     Splitter1.Width - Splitter2.Width);
  if TotalW > 0 then
  begin
    FSourceProportion := SourcePanel.Width / TotalW;
    FResourceProportion := ResourcePanel.Width / TotalW;
  end;
  RecalcAllChunkLayouts;
end;

procedure TProjectEditWindow.btnMenuClick(Sender: TObject);
var
  Pt: TPoint;
  MI: TMenuItem;
begin
  if FEditMenu = nil then
  begin
    FEditMenu := TPopupMenu.Create(Self);

    MI := TMenuItem.Create(FEditMenu);
    MI.Caption := rsMenuProjectReview;
    MI.Enabled := False;
    FEditMenu.Items.Add(MI);

    MI := TMenuItem.Create(FEditMenu);
    MI.Caption := rsMenuUploadExport;
    MI.OnClick := @OnMenuUploadExport;
    FEditMenu.Items.Add(MI);

    MI := TMenuItem.Create(FEditMenu);
    MI.Caption := rsMenuPrint;
    MI.Enabled := False;
    FEditMenu.Items.Add(MI);

    MI := TMenuItem.Create(FEditMenu);
    MI.Caption := rsMenuFeedback;
    MI.Enabled := False;
    FEditMenu.Items.Add(MI);

    MI := TMenuItem.Create(FEditMenu);
    MI.Caption := '-';
    FEditMenu.Items.Add(MI);

    MI := TMenuItem.Create(FEditMenu);
    MI.Caption := rsMenuMarkAllDone;
    MI.Enabled := False;
    FEditMenu.Items.Add(MI);

    MI := TMenuItem.Create(FEditMenu);
    MI.Caption := '-';
    FEditMenu.Items.Add(MI);

    MI := TMenuItem.Create(FEditMenu);
    MI.Caption := rsMenuSettings;
    MI.OnClick := @OnMenuSettings;
    FEditMenu.Items.Add(MI);

    if GetDeveloperTools then
    begin
      MI := TMenuItem.Create(FEditMenu);
      MI.Caption := rsMenuDevTools;
      MI.OnClick := @OnMenuDevTools;
      FEditMenu.Items.Add(MI);
    end;
  end;

  if Sender is TSpeedButton then
    Pt := TSpeedButton(Sender).ClientToScreen(
      Point(TSpeedButton(Sender).Width, 0))
  else
    Pt := btnMenu.ClientToScreen(Point(0, btnMenu.Height));
  FEditMenu.PopUp(Pt.X, Pt.Y);
end;

procedure TProjectEditWindow.OnMenuUploadExport(Sender: TObject);
var
  Choice: TExportChoice;
  SaveDlg: TSaveDialog;
  Err: string;
begin
  SaveCurrentChapter;
  Choice := ShowExportDialog(IsServerUser(MainWindow.FCurrentUser));
  case Choice of
    ecTStudio:
    begin
      SaveDlg := TSaveDialog.Create(Self);
      try
        SaveDlg.Filter := rsExportFilterEdit;
        SaveDlg.DefaultExt := rsTStudioExtEdit;
        if FSummary.DirName <> '' then
          SaveDlg.FileName := FSummary.DirName + '.tstudio'
        else
          SaveDlg.FileName := ExtractFileName(
            ExcludeTrailingPathDelimiter(FProjectPath)) + '.tstudio';
        SaveDlg.InitialDir := GetBackupLocation;
        if (SaveDlg.InitialDir = '') or not DirectoryExists(SaveDlg.InitialDir) then
          SaveDlg.InitialDir := GetEnvironmentVariable('HOME');
        if not SaveDlg.Execute then
          Exit;
        if not CreateTStudioPackage(FSummary.FullPath, SaveDlg.FileName, Err) then
        begin
          ShowMessage(rsExportFailedEdit + Err);
          Exit;
        end;
        ShowMessage(rsExportedEdit + SaveDlg.FileName);
      finally
        SaveDlg.Free;
      end;
    end;
    ecUSFM:
      MainWindow.DoExportUSFM(FSummary);
    ecServer:
      MainWindow.DoUploadToServer(FSummary);
  end;
end;

procedure TProjectEditWindow.OnMenuPrint(Sender: TObject);
begin
  ShowMessage('Print/PDF export is not yet implemented.');
end;

procedure TProjectEditWindow.OnMenuSettings(Sender: TObject);
var
  OldTheme, NewTheme: TAppTheme;
  OldSuite, NewSuite: string;
  OldLang, NewLang: string;
begin
  if ShowSettingsDialog(OldTheme, NewTheme, OldSuite, NewSuite,
                        OldLang, NewLang) then
  begin
    if NewTheme <> OldTheme then
      ApplyTheme;
    if NewLang <> OldLang then
      HotReloadInterfaceLanguage;
  end;
end;

procedure TProjectEditWindow.OnMenuDevTools(Sender: TObject);
begin
  ShowDevToolsWindow;
end;

procedure TProjectEditWindow.OnMenuProjectReview(Sender: TObject);
begin
  ShowMessage('Project Review is not yet implemented.');
end;

procedure TProjectEditWindow.OnMenuFeedback(Sender: TObject);
begin
  ShowMessage('Feedback is not yet implemented.');
end;

procedure TProjectEditWindow.OnMenuMarkAllDone(Sender: TObject);
begin
  ShowMessage('Mark All Chunks Done is not yet implemented.');
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
  LogInfo('ProjectEditForm.FormClose: saving blind edit chunk');
  SaveBlindEditChunk;
  LogInfo('ProjectEditForm.FormClose: clearing chunk panels');
  ClearChunkPanels;
  LogInfo('ProjectEditForm.FormClose: freeing FProject and FSourceRC');
  FreeAndNil(FBlindChunkNames);
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
      { Log + status-bar message. Don't force-close — transient failures
        (disk pressure, lock contention) would otherwise lose the user's
        in-memory work. Next tick may succeed; FormClose still has its
        own save attempt as a final boundary. }
      LogFmt(llWarn, 'AutoSaveTimerFire: save failed: %s', [E.Message]);
      lblStatus.Caption := rsAutoSaveFailedPrefix + E.Message;
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
  else if (Sender is TControl) and
     IsControlInPane(TControl(Sender), ResourceScrollBox) then
    BasePos := ResourceScrollBox.VertScrollBar.Position
  else
    BasePos := SourceScrollBox.VertScrollBar.Position;

  NewPos := BasePos - PixelStep;
  if NewPos < 0 then
    NewPos := 0;

  FSyncingScroll := True;
  try
    SourceScrollBox.VertScrollBar.Position := NewPos;
    TransScrollBox.VertScrollBar.Position := NewPos;
    ResourceScrollBox.VertScrollBar.Position := NewPos;
    FLastSourcePos := SourceScrollBox.VertScrollBar.Position;
    FLastTransPos := TransScrollBox.VertScrollBar.Position;
    FLastResourcePos := ResourceScrollBox.VertScrollBar.Position;
  finally
    FSyncingScroll := False;
  end;

  Handled := True;
end;

procedure TProjectEditWindow.ScrollSyncTimerFire(Sender: TObject);
var
  SourcePos, TransPos, ResPos, NewPos: Integer;
begin
  if FSyncingScroll then
    Exit;

  SourcePos := SourceScrollBox.VertScrollBar.Position;
  TransPos := TransScrollBox.VertScrollBar.Position;
  ResPos := ResourceScrollBox.VertScrollBar.Position;
  if (SourcePos = TransPos) and (TransPos = ResPos) then
  begin
    FLastSourcePos := SourcePos;
    FLastTransPos := TransPos;
    FLastResourcePos := ResPos;
    Exit;
  end;

  if SourcePos <> FLastSourcePos then
    NewPos := SourcePos
  else if TransPos <> FLastTransPos then
    NewPos := TransPos
  else if ResPos <> FLastResourcePos then
    NewPos := ResPos
  else
    NewPos := SourcePos;

  FSyncingScroll := True;
  try
    SourceScrollBox.VertScrollBar.Position := NewPos;
    TransScrollBox.VertScrollBar.Position := NewPos;
    ResourceScrollBox.VertScrollBar.Position := NewPos;
  finally
    FSyncingScroll := False;
  end;

  FLastSourcePos := SourceScrollBox.VertScrollBar.Position;
  FLastTransPos := TransScrollBox.VertScrollBar.Position;
  FLastResourcePos := ResourceScrollBox.VertScrollBar.Position;
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

{ Return True if a resource slug is a non-Bible resource (notes, questions, words) }
function IsHelpsResource(const ResSlug: string): Boolean;
var
  S: string;
begin
  S := LowerCase(ResSlug);
  Result := (S = 'tn') or (S = 'tq') or (S = 'tw') or (S = 'obs');
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

          { For text projects, skip non-Bible resources (tn, tq, tw) }
          if IsHelpsResource(ResSlug) then
            Continue;

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
      Dlg.Caption := rsSelectSourceText;
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
      BtnOK.Caption := rsBtnOK;
      BtnOK.ModalResult := mrOK;
      BtnOK.Default := True;
      BtnOK.Width := 80;
      BtnOK.Left := 600 - 80 - 12 - 80 - 8;
      BtnOK.Top := 8;

      BtnCancel := TButton.Create(Dlg);
      BtnCancel.Parent := BtnPanel;
      BtnCancel.Caption := rsBtnCancel;
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
  FLoadingLabel.Font.Height := -16;
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

{ Ensure companion resources (tn, tq, tw) are available for a Bible source text.
  Silently extracts them from the bundled archive if not already installed. }
procedure EnsureCompanionResources(const LangCode, BookCode: string);
var
  LibPath, ZipPath, Slug, DestDir: string;
  Companions: array[0..2] of string;
  I: Integer;
begin
  LibPath := GetLibraryPath;
  ZipPath := SourceExtractor.FindBundledZipPath;
  if ZipPath = '' then
    ZipPath := GetBundledResourceContainersZipPath;
  if (ZipPath = '') or (not FileExists(ZipPath)) then
    Exit;

  Companions[0] := LowerCase(LangCode) + '_' + LowerCase(BookCode) + '_tn';
  Companions[1] := LowerCase(LangCode) + '_' + LowerCase(BookCode) + '_tq';
  Companions[2] := LowerCase(LangCode) + '_bible_tw';

  for I := 0 to High(Companions) do
  begin
    Slug := Companions[I];
    DestDir := IncludeTrailingPathDelimiter(LibPath) + Slug;
    if DirectoryExists(DestDir) then
      Continue;
    ForceDirectories(DestDir);
    if not SourceExtractor.ExtractTsrc(ZipPath, Slug, DestDir) then
    begin
      { Not available in bundle — remove empty directory }
      RemoveDir(DestDir);
      LogFmt(llInfo, 'Companion resource %s not available in bundle', [Slug]);
    end
    else
      LogFmt(llInfo, 'Extracted companion resource: %s', [Slug]);
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

    { Ensure companion resources (tn, tq, tw) are available }
    EnsureCompanionResources(SourceOpt.SourceLangCode, ASummary.BookCode);

    { Find English ULB for save-chunking }
    FEnglishULBContentDir := FindEnglishULBContentDir(ASummary.BookCode);

    { Load source resource container }
    UpdateLoadingSplash(rsLoadingSourceText, 30);
    FSourceRC := TResourceContainer.Create('', ASummary.BookCode, SourceResourceID, '');
    FSourceRC.Book.LoadFromToc(FSourceContentDir);
    FSourceRC.Book.LoadContent(FSourceContentDir, '.usx');
    { Read source language direction from package.json (one level above content/) }
    FSourceRC.Direction := ReadResourceDirection(
      ExtractFileDir(ExcludeTrailingPathDelimiter(FSourceContentDir)));

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

    { Check for unresolved merge conflicts }
    if ProjectHasConflicts(FProjectPath) then
    begin
      HideLoadingSplash;
      ShowConflictResolver(FProjectPath, ASummary.BookName, ASummary.TargetLangName);
      { Reload project content after resolution }
      FProject.Free;
      FProject := TProject.Create(APath);
      FProject.LoadContent(FSourceContentDir);
      ShowLoadingSplash(rsLoadingChapter);
    end;

    { Show the appropriate view mode }
    case FCurrentViewMode of
      vmRead: ShowReadMode;
      vmBlindEdit: ShowBlindEditMode;
      vmEditReview: ShowEditReviewMode;
    end;
    UpdateModeButtons;

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
  btnChangeSource.Font.Height := -13;

  lblTransHeader.Left := TransLeft;
  lblTransHeader.Top := 2;
  lblTransLangHeader.Left := TransLeft;
  lblTransLangHeader.Top := 19;

  lblResourceHeader.Left := ResLeft + 8;
  lblResourceHeader.Top := 2;
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
  lblProjectTitle.Font.Color := P.HeaderText;
  lblChapterNum.Font.Color := clWhite;
  lblSourceHeader.Font.Color := P.TextPrimary;
  SourceLangHeader.Font.Color := P.TextSecondary;
  lblTransHeader.Font.Color := P.TextPrimary;
  lblTransLangHeader.Font.Color := P.TextSecondary;
  lblStatus.Font.Color := P.HeaderText;
  btnMenu.Font.Color := P.RailText;
  btnBack.Font.Color := P.RailText;
  btnHamburger.Font.Color := P.RailText;
  btnModeRead.Font.Color := P.RailText;
  btnModeBlindEdit.Font.Color := P.RailText;
  btnModeEditReview.Font.Color := P.RailText;
  btnPrevChapter.Font.Color := P.RailText;
  btnNextChapter.Font.Color := P.RailText;
  pnlChapterNav.Color := P.RailBg;
end;

{ Ensure companion resources (tn, tq, tw) are available for a Bible source text.
  Silently extracts them from the bundled archive if not already installed. }
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

  { Ensure companion resources are available for the new source }
  EnsureCompanionResources(LangCode, FBookCode);

  { Update source }
  FSourceLangCode := LangCode;
  FSourceResourceType := ResType;
  FSourceContentDir := NewContentDir;
  FEnglishULBContentDir := FindEnglishULBContentDir(FBookCode);

  FreeAndNil(FSourceRC);
  FSourceRC := TResourceContainer.Create(LangCode, FBookCode, ResType, '');
  FSourceRC.Book.LoadFromToc(FSourceContentDir);
  FSourceRC.Book.LoadContent(FSourceContentDir, '.usx');
  FSourceRC.Direction := ReadResourceDirection(NewSourceDir);

  { Update manifest source_translations to match new source }
  FProject.SetSourceTranslation(LangCode, ResType);

  { Reload project content with new source chunking }
  FProject.LoadContent(FSourceContentDir);

  { Update header }
  NewLangName := ReadSourceLanguageName(NewSourceDir);
  if NewLangName = '' then
    NewLangName := LangCode;
  SourceLangHeader.Caption := NewLangName + ' ' + UpperCase(ResType);
  UpdatePaneHeaders;

  { Update read mode source label if in read mode }
  if FCurrentViewMode = vmRead then
    FReadSourceLabel.Caption := FSourceRC.LanguageCode + ' ' +
      UpperCase(FSourceRC.ResourceType) + '  ✕';

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
  NextChunkStart, ChunkStartVerse, ChunkEndVerse: Integer;
begin
  DisplayChunks := nil;
  ChunkMap := nil;
  try
    { Save previous chapter first }
    SaveCurrentChapter;

    FCurrentChapterIndex := AIndex;

    { In Read mode, skip Edit-Review panel building — just update nav and content }
    if FCurrentViewMode = vmRead then
    begin
      UpdateChapterNav;
      LoadReadModeContent;
      UpdateStatus;
      Exit;
    end;

    { In Blind Edit mode, reload chunk display for the new chapter }
    if FCurrentViewMode = vmBlindEdit then
    begin
      UpdateChapterNav;
      SaveBlindEditChunk;
      FBlindChunkIndex := 0;
      if (FSourceRC <> nil) and (AIndex >= 0) and
         (AIndex < FSourceRC.Book.Chapters.Count) then
      begin
        FBlindChunkCount := FSourceRC.Book.Chapters[AIndex].Chunks.Count;
        if (FBlindChunkCount > 1) and
           (FSourceRC.Book.Chapters[AIndex].Chunks[0].Name = 'title') then
          FBlindChunkIndex := 1;
      end;
      LoadBlindEditChunk;
      UpdateStatus;
      Exit;
    end;
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
    ResourceScrollBox.DisableAutoSizing;
    try
      for I := 0 to SourceChapter.Chunks.Count - 1 do
      begin
        SourceChunk := SourceChapter.Chunks[I];

        { Convert USX source to plain text }
        { Pass raw USX to the chunk panel for direct HTML rendering }
        SourceText := SourceChunk.Content;

        { Build verse label }
        NextChunkStart := 0;
        if SourceChunk.Name = 'title' then
          ChunkLabel := rsChunkTitle
        else
          ChunkLabel := rsChunkVersePrefix + SourceChunk.Name;
        { Determine verse range for display label and resource filtering }
        ChunkStartVerse := StrToIntDef(SourceChunk.Name, 0);
        if I < SourceChapter.Chunks.Count - 1 then
        begin
          NextChunkStart := StrToIntDef(SourceChapter.Chunks[I + 1].Name, 0);
          if (NextChunkStart > 0) and (ChunkStartVerse > 0) then
          begin
            ChunkEndVerse := NextChunkStart - 1;
            if ChunkEndVerse > ChunkStartVerse then
              ChunkLabel := rsChunkVersePrefix + SourceChunk.Name + rsChunkVerseRangeJoin +
                IntToStr(ChunkEndVerse);
          end
          else
            ChunkEndVerse := ChunkStartVerse;
        end
        else
        begin
          { Last chunk — extends to end of chapter }
          if ChunkStartVerse > 0 then
            ChunkEndVerse := 999
          else
            ChunkEndVerse := 0; { title chunk }
        end;

        { Get translated text for this chunk }
        TransText := '';
        if (DisplayChunks <> nil) and (I < DisplayChunks.Count) then
          TransText := DisplayChunks[I].Content;

        { Check if chunk is finished }
        IsFinished := FProject.IsFinished(SourceChapter.ID, SourceChunk.Name);

        FChunkPanels[I] := TChunkPanel.Create(Self,
          SourceScrollBox, TransScrollBox, ResourceScrollBox,
          SourceText, TransText, SourceChapter.ID, SourceChunk.Name,
          ChunkLabel, ChunkStartVerse, ChunkEndVerse, IsFinished, FProject);
      end;
    finally
      SourceScrollBox.EnableAutoSizing;
      TransScrollBox.EnableAutoSizing;
      ResourceScrollBox.EnableAutoSizing;
    end;

    { Load resources for each chunk }
    for I := 0 to Length(FChunkPanels) - 1 do
      FChunkPanels[I].LoadResources;

    { Recalculate chunk layout now that auto-sizing has set final widths }
    RecalcAllChunkLayouts;

    UpdateChapterNav;
    UpdateStatus;

    { Some controls created during chunk panel build can steal focus and
      auto-scroll mid-chapter. Force both panes back to the first chunk. }
    SourceScrollBox.VertScrollBar.Position := 0;
    TransScrollBox.VertScrollBar.Position := 0;
    ResourceScrollBox.VertScrollBar.Position := 0;
    FLastSourcePos := 0;
    FLastTransPos := 0;
    FLastResourcePos := 0;
    AttachWheelHandlers(SourceScrollBox);
    AttachWheelHandlers(TransScrollBox);
    AttachWheelHandlers(ResourceScrollBox);
    FChapterDirty := False;
    { Select first verse chunk (skip title) for initial display }
    if Length(FChunkPanels) > 1 then
      SetSelectedChunkIndex(1)
    else if Length(FChunkPanels) > 0 then
      SetSelectedChunkIndex(0)
    else
      FSelectedChunkIndex := -1;
    ActiveControl := SourceScrollBox;

    { TIpHtmlPanel.GetContentSize returns accurate values only after the
      panel has been painted.  Fire a one-shot timer so the recalc runs
      after the next paint cycle. }
    FRecalcTimer.Enabled := True;
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
  KeepNames: TStringList;
  ChunkPath: string;
begin
  { Blind edit saves per-chunk independently }
  if FCurrentViewMode = vmBlindEdit then
  begin
    SaveBlindEditChunk;
    Exit;
  end;
  if not FChapterDirty then
    Exit;
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

      { Build the list of chunk names we intend to keep this save, then
        delete only the .txt files in the chapter dir whose base name is
        not in that list. Avoids the previous behavior of wiping every
        chunk file and rewriting all of them — which churned mtimes and
        produced noisy git diffs even when nothing meaningful changed. }
      KeepNames := TStringList.Create;
      try
        for I := 0 to SaveChunks.Count - 1 do
          if ChunkHasContent(SaveChunks[I].Content) then
            KeepNames.Add(SaveChunks[I].Name);
        RemoveStaleChunkFiles(SaveContentDir + SourceChapter.ID, '.txt',
                              KeepNames);
      finally
        FreeAndNil(KeepNames);
      end;

      SaveChapter := TChapter.Create(SourceChapter.ID);
      try
        for I := 0 to SaveChunks.Count - 1 do
        begin
          { Scrub any trailing run of bare verse markers (e.g.
            '\v 8 \v 11 \v 14') before deciding whether the chunk has
            content. These run-on stubs come from the merge -> split
            round-trip when neighboring source chunks are empty. }
          SaveChunks[I].Content := StripTrailingEmptyVerseMarkers(
            SaveChunks[I].Content);

          { Skip stub chunks that hold only verse/paragraph markers
            inherited from the source template — they're not real
            translation work yet, and writing them creates the
            "duplicate-looking" file fanout users see right after
            saving the first chunk in a chapter. }
          if not ChunkHasContent(SaveChunks[I].Content) then
            Continue;
          SaveChapter.AddChunk(TChunk.Create(SaveChunks[I].Name));
          { Load any current on-disk content first so TChunk.SetContent
            can compare and only flip FDirty when the new content really
            differs. SaveDirtyChunks will then skip the unchanged ones. }
          ChunkPath := IncludeTrailingPathDelimiter(
                         SaveContentDir + SourceChapter.ID) +
                       SaveChunks[I].Name + '.txt';
          if FileExists(ChunkPath) then
            SaveChapter.Chunks[SaveChapter.Chunks.Count - 1].LoadFromFile(
              ChunkPath);
          SaveChapter.Chunks[SaveChapter.Chunks.Count - 1].Content :=
            SaveChunks[I].Content;
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

  FChapterDirty := False;
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
  FChapterDirty := True;
  if CB.Checked then
  begin
    { Flush any in-progress memo to disk BEFORE marking the chunk
      finished. Otherwise the manifest could record a "finished" key
      pointing at unsaved text — power-loss between the manifest write
      and a later chapter save would leave the project inconsistent. }
    for I := 0 to Length(FChunkPanels) - 1 do
      if FChunkPanels[I].FFinishedCheck = CB then
      begin
        if FChunkPanels[I].FEditing then
          FChunkPanels[I].SetEditing(False);  { also writes chapter to disk }
        FProject.MarkFinished(CB.Hint, CB.HelpKeyword);
        FChunkPanels[I].FEditButton.Enabled := False;
        FChunkPanels[I].FIsFinished := True;
        FChunkPanels[I].RefreshTransHtml;
        FChunkPanels[I].UpdateFinishedVisuals;
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
        FChunkPanels[I].FIsFinished := False;
        FChunkPanels[I].RefreshTransHtml;
        FChunkPanels[I].UpdateFinishedVisuals;
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
  if FChapterDirty then
  begin
    SaveCurrentChapter;
    lblStatus.Caption := rsSavedAtPrefix + TimeToStr(Now);
  end;
end;

procedure TProjectEditWindow.OnChunkMemoChange(Sender: TObject);
begin
  FChapterDirty := True;
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

procedure StyleTabButton(Btn: TButton; Active: Boolean);
begin
  if Active then
  begin
    Btn.Font.Style := [fsBold];
    Btn.Font.Color := clWhite;
    Btn.Color := $00B5652D;
  end
  else
  begin
    Btn.Font.Style := [];
    Btn.Font.Color := clBlack;
    Btn.Color := clBtnFace;
  end;
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
end;

function TProjectEditWindow.ResourceDirFor(const ResourceID: string): string;
var
  LangCode: string;
begin
  Result := '';
  if FProject = nil then
    Exit;
  { Use the currently active source language, not the manifest's original —
    this ensures resources match when the user switches source texts }
  LangCode := FSourceLangCode;
  if LangCode = '' then
    LangCode := 'en';
  Result := GetLibraryPath + LangCode + '_' + FBookCode + '_' + ResourceID;
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

    { Skip resource files outside the chunk's verse range }
    if (ChunkStart > EndV) or (ChunkEnd < StartV) then
      Continue;

    SL := TStringList.Create;
    try
      SL.LoadFromFile(Files[I]);
      if Trim(SL.Text) <> '' then
      begin
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
        if (V < ChunkStart) or (V > ChunkEnd) then
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


{ ---- TChunkPanel ---- }

constructor TChunkPanel.Create(AOwnerForm: TProjectEditWindow;
  ASourceParent, ATransParent, AResourceParent: TScrollBox;
  const ASourceText, ATransText, AChapterID, AChunkName, AVerseLabel: string;
  AStartVerse, AEndVerse: Integer; AFinished: Boolean; AProject: TProject);
var
  PanelHeight: Integer;
  HeaderHeight, FooterHeight, BodyTop: Integer;
  HeaderLabel: TLabel;
  TabBarHeight: Integer;
begin
  inherited Create;
  FOwnerForm := AOwnerForm;
  FChapterID := AChapterID;
  FChunkName := AChunkName;
  FProject := AProject;
  FEditing := False;
  FSourceText := ASourceText;
  FTransText := ATransText;
  FStartVerse := AStartVerse;
  FEndVerse := AEndVerse;
  FSourceBadgeColor := $00B5652D;
  FTransBadgeColor := $009A8A00;
  FIsFinished := AFinished;
  FActiveResTab := rtNotes;
  HeaderHeight := 28;
  FooterHeight := 34;
  BodyTop := HeaderHeight + 2;
  TabBarHeight := 28;
  PanelHeight := 120; { initial estimate, RecalcLayout will fix }

  { Source panel — alTop stacks by Top value, so set high to append at bottom }
  FSourcePanel := TPanel.Create(ASourceParent);
  FSourcePanel.Parent := ASourceParent;
  FSourcePanel.Top := ASourceParent.ControlCount * 100;
  FSourcePanel.Align := alTop;
  FSourcePanel.Height := PanelHeight;
  FSourcePanel.BorderSpacing.Bottom := 10;
  FSourcePanel.BevelOuter := bvLowered;
  FSourcePanel.Color := clWhite;

  { Chunk header label }
  HeaderLabel := TLabel.Create(FSourcePanel);
  HeaderLabel.Parent := FSourcePanel;
  HeaderLabel.Left := 10;
  HeaderLabel.Top := 6;
  HeaderLabel.Caption := AVerseLabel;
  HeaderLabel.Font.Height := -15;
  HeaderLabel.Font.Style := [fsBold];
  HeaderLabel.Font.Color := $8A8A8A;
  HeaderLabel.OnClick := @AOwnerForm.OnChunkPanelClick;

  { Source HTML display }
  FSourceHtml := TIpHtmlPanel.Create(FSourcePanel);
  FSourceHtml.Parent := FSourcePanel;
  FSourceHtml.Left := 2;
  FSourceHtml.Top := BodyTop;
  FSourceHtml.Anchors := [akTop, akLeft, akRight, akBottom];
  FSourceHtml.Width := FSourcePanel.ClientWidth - 4;
  FSourceHtml.Height := PanelHeight - BodyTop - 2;
  FSourceHtml.DefaultTypeFace := 'Roboto';
  FSourceHtml.DefaultFontSize := 13;
  FSourceHtml.BgColor := clWhite;
  FSourceHtml.BorderStyle := bsNone;
  FSourceHtml.OnClick := @AOwnerForm.OnChunkPanelClick;
  FSourcePanel.OnClick := @AOwnerForm.OnChunkPanelClick;
  RefreshSourceHtml;

  { Translation panel — alTop stacks by Top value, so set high to append at bottom }
  FTransPanel := TPanel.Create(ATransParent);
  FTransPanel.Parent := ATransParent;
  FTransPanel.Top := ATransParent.ControlCount * 100;
  FTransPanel.Align := alTop;
  FTransPanel.Height := PanelHeight;
  FTransPanel.BorderSpacing.Bottom := 10;
  FTransPanel.BevelOuter := bvLowered;
  FTransPanel.Color := clWhite;

  { Translation HTML display (read-only view) }
  FTransHtml := TIpHtmlPanel.Create(FTransPanel);
  FTransHtml.Parent := FTransPanel;
  FTransHtml.Left := 2;
  FTransHtml.Top := BodyTop;
  FTransHtml.Anchors := [akTop, akLeft, akRight, akBottom];
  FTransHtml.Width := FTransPanel.ClientWidth - 4;
  FTransHtml.Height := PanelHeight - BodyTop - FooterHeight - 2;
  FTransHtml.DefaultTypeFace := 'Roboto';
  FTransHtml.DefaultFontSize := 13;
  FTransHtml.BgColor := clWhite;
  FTransHtml.BorderStyle := bsNone;
  FTransHtml.OnClick := @AOwnerForm.OnChunkPanelClick;
  FTransPanel.OnClick := @AOwnerForm.OnChunkPanelClick;
  RefreshTransHtml;

  { Edit memo (hidden initially) }
  FTransMemo := TMemo.Create(FTransPanel);
  FTransMemo.Parent := FTransPanel;
  FTransMemo.Left := 8;
  FTransMemo.Top := BodyTop;
  FTransMemo.Anchors := [akTop, akLeft, akRight, akBottom];
  FTransMemo.Width := FTransPanel.ClientWidth - 16;
  FTransMemo.Height := PanelHeight - BodyTop - FooterHeight - 6;
  FTransMemo.Text := ATransText;
  FTransMemo.Font.Name := 'Roboto';
  FTransMemo.Font.Height := -17;
  FTransMemo.WordWrap := True;
  FTransMemo.ScrollBars := ssAutoVertical;
  FTransMemo.Visible := False;
  if SameText(AOwnerForm.FLayoutDirection, 'rtl') then
    FTransMemo.BiDiMode := bdRightToLeft
  else
    FTransMemo.BiDiMode := bdLeftToRight;
  FTransMemo.OnExit := @AOwnerForm.OnChunkMemoExit;
  FTransMemo.OnChange := @AOwnerForm.OnChunkMemoChange;
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

  { If finished, disable editing }
  if AFinished then
    FEditButton.Enabled := False;

  { Resource panel }
  FResourcePanel := TPanel.Create(AResourceParent);
  FResourcePanel.Parent := AResourceParent;
  FResourcePanel.Top := AResourceParent.ControlCount * 100;
  FResourcePanel.Align := alTop;
  FResourcePanel.Height := PanelHeight;
  FResourcePanel.BorderSpacing.Bottom := 10;
  FResourcePanel.BevelOuter := bvLowered;
  FResourcePanel.Color := clWhite;

  { Per-chunk tab bar }
  FResTabBar := TPanel.Create(FResourcePanel);
  FResTabBar.Parent := FResourcePanel;
  FResTabBar.Align := alTop;
  FResTabBar.Height := TabBarHeight;
  FResTabBar.BevelOuter := bvNone;
  FResTabBar.Color := $00F0F0F0;

  FBtnTabNotes := TButton.Create(FResTabBar);
  FBtnTabNotes.Parent := FResTabBar;
  FBtnTabNotes.SetBounds(4, 2, 70, TabBarHeight - 4);
  FBtnTabNotes.Caption := rsTabNotes;
  FBtnTabNotes.Font.Height := -12;
  FBtnTabNotes.OnClick := @OnResTabClick;

  FBtnTabWords := TButton.Create(FResTabBar);
  FBtnTabWords.Parent := FResTabBar;
  FBtnTabWords.SetBounds(78, 2, 70, TabBarHeight - 4);
  FBtnTabWords.Caption := rsTabWords;
  FBtnTabWords.Font.Height := -12;
  FBtnTabWords.OnClick := @OnResTabClick;

  FBtnTabQuestions := TButton.Create(FResTabBar);
  FBtnTabQuestions.Parent := FResTabBar;
  FBtnTabQuestions.SetBounds(152, 2, 84, TabBarHeight - 4);
  FBtnTabQuestions.Caption := rsTabQuestions;
  FBtnTabQuestions.Font.Height := -12;
  FBtnTabQuestions.OnClick := @OnResTabClick;

  { Resource HTML content }
  FResHtml := TIpHtmlPanel.Create(FResourcePanel);
  FResHtml.Parent := FResourcePanel;
  FResHtml.Align := alClient;
  FResHtml.DefaultTypeFace := 'Noto Sans';
  FResHtml.DefaultFontSize := 12;
  FResHtml.BgColor := clWhite;
  FResHtml.BorderStyle := bsNone;
  FResHtml.OnHotClick := @OnResHotClick;

  SetSelected(False);
end;

destructor TChunkPanel.Destroy;
begin
  FreeAndNil(FSourcePanel);
  FreeAndNil(FTransPanel);
  FreeAndNil(FResourcePanel);
  inherited Destroy;
end;

procedure TChunkPanel.RefreshSourceHtml;
var
  Body, SrcDir: string;
begin
  Body := UsxToHtml(FSourceText, ColorToHtmlHex(FSourceBadgeColor));
  if (FOwnerForm <> nil) and (FOwnerForm.FSourceRC <> nil) then
    SrcDir := FOwnerForm.FSourceRC.Direction
  else
    SrcDir := 'ltr';
  FSourceHtml.SetHtmlFromStr(WrapInHtmlDoc(Body, 'Roboto', 13, clWhite, SrcDir));
end;

procedure TChunkPanel.RefreshTransHtml;
var
  Body, TextColor, TgtDir: string;
begin
  if FIsFinished then
    TextColor := 'green'
  else if FTransText = '' then
    TextColor := 'gray'
  else
    TextColor := 'black';
  Body := USFMToHtml(FTransText, FTransBadgeColor, TextColor);
  if Body = '' then
    Body := '&nbsp;';
  if FOwnerForm <> nil then
    TgtDir := FOwnerForm.FLayoutDirection
  else
    TgtDir := 'ltr';
  FTransHtml.SetHtmlFromStr(WrapInHtmlDoc(Body, 'Roboto', 13, clWhite, TgtDir));
end;

procedure TChunkPanel.RecalcLayout;
var
  SourceContentH, TransContentH, PanelHeight: Integer;
  HeaderHeight, FooterHeight, BodyTop, Padding: Integer;
  ContentSize: TSize;
begin
  HeaderHeight := 28;
  FooterHeight := 34;
  BodyTop := HeaderHeight + 2;
  Padding := 8;

  { Force a synchronous paint so that GetContentSize returns an
    up-to-date page rect at the current panel width. }
  FSourceHtml.Update;
  FTransHtml.Update;

  ContentSize := FSourceHtml.GetContentSize;
  SourceContentH := ContentSize.cy;
  if SourceContentH < 30 then
    SourceContentH := 30;

  ContentSize := FTransHtml.GetContentSize;
  if FTransText <> '' then
    TransContentH := ContentSize.cy
  else
    TransContentH := 30;
  if TransContentH < 30 then
    TransContentH := 30;

  { Row height driven by source and translation only.
    Resource panel matches that height; its HTML panel scrolls internally
    if the resource list is taller than the available space. }
  PanelHeight := BodyTop + SourceContentH + Padding;
  if BodyTop + TransContentH + FooterHeight + Padding > PanelHeight then
    PanelHeight := BodyTop + TransContentH + FooterHeight + Padding;

  FSourcePanel.Height := PanelHeight;
  FTransPanel.Height := PanelHeight;
  FResourcePanel.Height := PanelHeight;
end;

procedure TChunkPanel.ForceHtmlRelayout;
begin
  { Re-render HTML at current panel width so GetContentSize is accurate }
  RefreshSourceHtml;
  RefreshTransHtml;
end;

procedure TChunkPanel.SetEditing(AEdit: Boolean);
begin
  if FFinishedCheck.Checked and AEdit then
    Exit;

  FEditing := AEdit;
  FTransHtml.Visible := not AEdit;
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
    { Per PROJECT.md auto-save spec: chunks must be written to disk when
      editing is disabled. SaveContent only updates the in-memory copy,
      so flush the chapter explicitly so the chunk .txt files match. }
    if FOwnerForm <> nil then
    begin
      FOwnerForm.FChapterDirty := True;
      FOwnerForm.SaveCurrentChapter;
    end;
    FEditButton.Caption := #9998;
  end;
end;

procedure TChunkPanel.SaveContent;
begin
  if FEditing then
  begin
    FTransText := FTransMemo.Text;
    RefreshTransHtml;
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
    FResourcePanel.BevelColor := $00B8792F;
  end
  else
  begin
    FSourcePanel.BevelColor := $00D0D0D0;
    FTransPanel.BevelColor := $00D0D0D0;
    FResourcePanel.BevelColor := $00D0D0D0;
  end;
end;

function TChunkPanel.OwnsControl(AObj: TObject): Boolean;
begin
  Result := (AObj = FSourcePanel) or (AObj = FTransPanel) or
            (AObj = FResourcePanel) or
            (AObj = FSourceHtml) or (AObj = FTransHtml) or
            (AObj = FResHtml) or
            (AObj = FTransMemo) or (AObj = FFinishedToggleBtn) or
            (AObj = FEditButton) or
            (AObj = FBtnTabNotes) or (AObj = FBtnTabWords) or
            (AObj = FBtnTabQuestions);
end;

function TChunkPanel.GetHeight: Integer;
begin
  Result := FSourcePanel.Height;
end;

procedure TChunkPanel.LoadResources;
var
  NotesList, WordsList, QuestionsList, Display: TStringList;
  StartV, EndV: Integer;
begin
  StartV := FStartVerse;
  EndV := FEndVerse;

  { Title chunk (verse 0) — no verse-based resources apply }
  if (StartV = 0) and (EndV < 1) then
  begin
    FBtnTabNotes.Visible := False;
    FBtnTabWords.Visible := False;
    FBtnTabQuestions.Visible := False;
    FResTabBar.Visible := False;
    FResHtml.SetHtmlFromStr(WrapInHtmlDoc('', 'Noto Sans', 12, clWhite));
    SetLength(FResourceSections, 0);
    Exit;
  end;

  NotesList := TStringList.Create;
  WordsList := TStringList.Create;
  QuestionsList := TStringList.Create;
  Display := TStringList.Create;
  try
    FOwnerForm.CollectChunkResources(FChapterID, StartV, EndV,
      FOwnerForm.ResourceDirFor('tn'), NotesList);
    FOwnerForm.CollectWordsResources(FChapterID, StartV, EndV, WordsList);
    FOwnerForm.CollectChunkResources(FChapterID, StartV, EndV,
      FOwnerForm.ResourceDirFor('tq'), QuestionsList);

    FBtnTabNotes.Visible := NotesList.Count > 0;
    FBtnTabWords.Visible := WordsList.Count > 0;
    FBtnTabQuestions.Visible := QuestionsList.Count > 0;

    { Auto-select first available tab }
    if (FActiveResTab = rtNotes) and (NotesList.Count = 0) then
      if WordsList.Count > 0 then FActiveResTab := rtWords else
      if QuestionsList.Count > 0 then FActiveResTab := rtQuestions;
    if (FActiveResTab = rtWords) and (WordsList.Count = 0) then
      if NotesList.Count > 0 then FActiveResTab := rtNotes else
      if QuestionsList.Count > 0 then FActiveResTab := rtQuestions;
    if (FActiveResTab = rtQuestions) and (QuestionsList.Count = 0) then
      if NotesList.Count > 0 then FActiveResTab := rtNotes else
      if WordsList.Count > 0 then FActiveResTab := rtWords;

    StyleTabButton(FBtnTabNotes, FActiveResTab = rtNotes);
    StyleTabButton(FBtnTabWords, FActiveResTab = rtWords);
    StyleTabButton(FBtnTabQuestions, FActiveResTab = rtQuestions);

    case FActiveResTab of
      rtNotes: Display.Assign(NotesList);
      rtWords: Display.Assign(WordsList);
      rtQuestions: Display.Assign(QuestionsList);
    end;

    FResourceSections := ParseResourceSections(Display.Text);

    if (NotesList.Count = 0) and (WordsList.Count = 0) and (QuestionsList.Count = 0) then
      FResHtml.SetHtmlFromStr(WrapInHtmlDoc(
        '<p style="color:#999;">No resources available.</p>',
        'Noto Sans', 12, clWhite))
    else
      FResHtml.SetHtmlFromStr(WrapInHtmlDoc(
        ResourceHeadingsToHtml(FResourceSections), 'Noto Sans', 12, clWhite));
  finally
    NotesList.Free;
    WordsList.Free;
    QuestionsList.Free;
    Display.Free;
  end;
end;

procedure TChunkPanel.OnResTabClick(Sender: TObject);
begin
  if Sender = FBtnTabNotes then
    FActiveResTab := rtNotes
  else if Sender = FBtnTabWords then
    FActiveResTab := rtWords
  else if Sender = FBtnTabQuestions then
    FActiveResTab := rtQuestions;
  LoadResources;
  RecalcLayout;
end;

procedure TChunkPanel.OnResHotClick(Sender: TObject);
var
  URL: string;
  Idx: Integer;
  F: TForm;
  Html: TIpHtmlPanel;
  CloseBtn: TButton;
  IndexLabel: string;
  Heading, Body, BodyHtml, FooterHtml: string;
  Pal: TThemePalette;
begin
  URL := FResHtml.HotURL;
  if Pos('section:', URL) <> 1 then
    Exit;
  Idx := StrToIntDef(Copy(URL, Length('section:') + 1, MaxInt), -1);
  if (Idx < 0) or (Idx >= Length(FResourceSections)) then
    Exit;

  Heading := FResourceSections[Idx].Heading;
  Body := FResourceSections[Idx].Body;
  Pal := GetThemePalette(GetEffectiveTheme);

  { Build footer link based on active tab }
  case FActiveResTab of
    rtNotes: IndexLabel := 'NOTES INDEX';
    rtWords: IndexLabel := 'WORDS INDEX';
    rtQuestions: IndexLabel := 'QUESTIONS INDEX';
  end;
  FooterHtml := '<p style="margin:16px 0 8px 0;font-weight:bold;">' +
    '<font color="#00897B">' + IndexLabel + '</font></p>';

  BodyHtml := '<h3 style="margin:4px 0 8px 0;color:#00897B;">' + Heading + '</h3>' +
    ResourceBodyToHtml(Body) + FooterHtml;

  F := TForm.CreateNew(FOwnerForm);
  try
    F.Position := poMainFormCenter;
    F.BorderStyle := bsSizeToolWin;
    F.Caption := Heading;
    F.Font.Name := 'Noto Sans';
    F.Width := 500;
    F.Height := 500;
    F.Color := Pal.PanelBg;

    { Close button at top }
    CloseBtn := TButton.Create(F);
    CloseBtn.Parent := F;
    CloseBtn.Align := alTop;
    CloseBtn.Height := 30;
    CloseBtn.Caption := rsCloseBtn;
    CloseBtn.Font.Height := -14;
    CloseBtn.ModalResult := mrClose;

    Html := TIpHtmlPanel.Create(F);
    Html.Parent := F;
    Html.Align := alClient;
    Html.DefaultFontSize := 13;
    Html.SetHtmlFromStr(WrapInHtmlDoc(BodyHtml, 'Noto Sans', 13, Pal.PanelBg));

    F.ShowModal;
  finally
    F.Free;
  end;
end;

end.
