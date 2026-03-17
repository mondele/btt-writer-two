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
  rsMenuUploadExport = 'Upload/Export';
  rsMenuPrint = 'Print';
  rsMenuSettings = 'Settings';
  rsMenuProjectReview = 'Project Review';
  rsMenuFeedback = 'Feedback';
  rsMenuMarkAllDone = 'Mark All Chunks Done';
  rsExportFilterEdit = 'Translation Studio Package (*.tstudio)|*.tstudio|All files|*.*';
  rsTStudioExtEdit = 'tstudio';
  rsExportFailedEdit = 'Export failed: ';
  rsExportedEdit = 'Exported: ';

type
  TResourceTab = (rtNotes, rtWords, rtQuestions);

  TResourceSection = record
    Heading: string;
    Body: string;
  end;
  TResourceSectionArray = array of TResourceSection;

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
    procedure OnMenuProjectReview(Sender: TObject);
    procedure OnMenuFeedback(Sender: TObject);
    procedure OnMenuMarkAllDone(Sender: TObject);
  private
    FRecalcTimer: TTimer;
    FSourceProportion: Double;
    FResourceProportion: Double;
    FEditMenu: TPopupMenu;
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
  UserProfile, GiteaClient, GitUtils, ConflictResolver;

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
  ABgColor: TColor): string;
begin
  Result := '<html><head><style>' +
    'body { font-family: ' + AFontName + '; font-size: ' + IntToStr(AFontSize) +
    'pt; margin: 4px; background-color: ' + ColorToHtmlHex(ABgColor) + '; }' +
    '</style></head><body>' + ABody + '</body></html>';
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
  ApplyFontRecursive(Self, 'Noto Sans');
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

  RecalcAllChunkLayouts;
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
  end;

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
begin
  if ShowSettingsDialog(OldTheme, NewTheme, OldSuite, NewSuite) then
  begin
    if NewTheme <> OldTheme then
      ApplyTheme;
  end;
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
  lblChapterNav.Font.Color := P.HeaderText;
  lblChapterNum.Font.Color := P.HeaderText;
  lblSourceHeader.Font.Color := P.TextPrimary;
  SourceLangHeader.Font.Color := P.TextSecondary;
  lblTransHeader.Font.Color := P.TextPrimary;
  lblTransLangHeader.Font.Color := P.TextSecondary;
  lblStatus.Font.Color := P.HeaderText;
  btnMenu.Font.Color := P.RailText;
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
  NextChunkStart, ChunkStartVerse, ChunkEndVerse: Integer;
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
    ActiveControl := btnBack;

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
begin
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
    FProject.MarkFinished(CB.Hint, CB.HelpKeyword);
    for I := 0 to Length(FChunkPanels) - 1 do
      if FChunkPanels[I].FFinishedCheck = CB then
      begin
        if FChunkPanels[I].FEditing then
          FChunkPanels[I].SetEditing(False);
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
  FBtnTabNotes.Caption := 'Notes';
  FBtnTabNotes.Font.Height := -12;
  FBtnTabNotes.OnClick := @OnResTabClick;

  FBtnTabWords := TButton.Create(FResTabBar);
  FBtnTabWords.Parent := FResTabBar;
  FBtnTabWords.SetBounds(78, 2, 70, TabBarHeight - 4);
  FBtnTabWords.Caption := 'Words';
  FBtnTabWords.Font.Height := -12;
  FBtnTabWords.OnClick := @OnResTabClick;

  FBtnTabQuestions := TButton.Create(FResTabBar);
  FBtnTabQuestions.Parent := FResTabBar;
  FBtnTabQuestions.SetBounds(152, 2, 84, TabBarHeight - 4);
  FBtnTabQuestions.Caption := 'Questions';
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
  Body: string;
begin
  Body := UsxToHtml(FSourceText, ColorToHtmlHex(FSourceBadgeColor));
  FSourceHtml.SetHtmlFromStr(WrapInHtmlDoc(Body, 'Roboto', 13, clWhite));
end;

procedure TChunkPanel.RefreshTransHtml;
var
  Body, TextColor: string;
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
  FTransHtml.SetHtmlFromStr(WrapInHtmlDoc(Body, 'Roboto', 13, clWhite));
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
    CloseBtn.Caption := 'X CLOSE';
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
