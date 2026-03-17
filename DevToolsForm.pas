unit DevToolsForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

procedure ShowDevToolsWindow;

implementation

uses
  Forms, Controls, Graphics, StdCtrls, ComCtrls, ExtCtrls, Grids, LCLType,
  ThemePalette, AppSettings, AppLog, DataPaths,
  BibleBook, BibleChapter, BibleChunk, Globals;

resourcestring
  rsDevToolsTitle = 'Developer Tools';
  rsTabLog = 'Log Viewer';
  rsTabChunkCompare = 'Chunk Comparison';
  rsRefreshLog = 'Refresh';
  rsClearLog = 'Clear';
  rsRunComparison = 'Run Comparison';
  rsComparing = 'Comparing...';
  rsNoEnglishULB = 'No English ULB source texts found in library.';
  rsCompareIntro = 'Compares installed source text chunk boundaries against English ULB baseline.';

const
  BOOK_ORDER: array[0..65] of string = (
    'gen','exo','lev','num','deu','jos','jdg','rut','1sa','2sa','1ki','2ki',
    '1ch','2ch','ezr','neh','est','job','psa','pro','ecc','sng','isa','jer',
    'lam','ezk','dan','hos','jol','amo','oba','jon','mic','nam','hab','zep',
    'hag','zec','mal','mat','mrk','luk','jhn','act','rom','1co','2co','gal',
    'eph','php','col','1th','2th','1ti','2ti','tit','phm','heb','jas','1pe',
    '2pe','1jn','2jn','3jn','jud','rev'
  );

function BookSortIndex(const BookCode: string): Integer;
var
  I: Integer;
  C: string;
begin
  C := LowerCase(Trim(BookCode));
  for I := Low(BOOK_ORDER) to High(BOOK_ORDER) do
    if BOOK_ORDER[I] = C then
      Exit(I);
  Result := 9999;
end;

type
  { Record for a chunk comparison result row }
  TChunkCompareRow = record
    Source: string;
    BookCode: string;
    Status: string;
    ChaptersAffected: string;
    Details: string;
    BookIndex: Integer;
  end;
  TChunkCompareRowArray = array of TChunkCompareRow;

  TDevToolsWindow = class(TForm)
  private
    Pages: TPageControl;
    TabLog: TTabSheet;
    TabChunk: TTabSheet;
    { Log tab }
    LogGrid: TStringGrid;
    pnlLogButtons: TPanel;
    btnRefresh: TButton;
    btnClear: TButton;
    lblLogPath: TLabel;
    { Chunk tab }
    ChunkGrid: TStringGrid;
    pnlChunkTop: TPanel;
    btnRunCompare: TButton;
    lblChunkInfo: TLabel;
    lblStatus: TLabel;
    procedure RefreshLogClick(Sender: TObject);
    procedure ClearLogClick(Sender: TObject);
    procedure RunCompareClick(Sender: TObject);
    procedure LoadLogFile;
    procedure DoChunkComparison;
    procedure LogGridPrepareCanvas(Sender: TObject; aCol, aRow: Integer;
      aState: TGridDrawState);
    procedure ChunkGridPrepareCanvas(Sender: TObject; aCol, aRow: Integer;
      aState: TGridDrawState);
  public
    constructor CreateWindow(AOwner: TComponent);
  end;

constructor TDevToolsWindow.CreateWindow(AOwner: TComponent);
var
  P: TThemePalette;
begin
  inherited Create(AOwner);
  P := GetThemePalette(GetEffectiveTheme);
  Position := poScreenCenter;
  Width := 850;
  Height := 580;
  Caption := rsDevToolsTitle;
  Color := P.PanelBg;
  BorderIcons := [biSystemMenu, biMaximize];

  Pages := TPageControl.Create(Self);
  Pages.Parent := Self;
  Pages.Align := alClient;

  { ---- Log Viewer Tab ---- }
  TabLog := TTabSheet.Create(Pages);
  TabLog.PageControl := Pages;
  TabLog.Caption := rsTabLog;

  pnlLogButtons := TPanel.Create(TabLog);
  pnlLogButtons.Parent := TabLog;
  pnlLogButtons.Align := alTop;
  pnlLogButtons.Height := 40;
  pnlLogButtons.BevelOuter := bvNone;
  pnlLogButtons.Color := P.PanelBg;

  btnRefresh := TButton.Create(pnlLogButtons);
  btnRefresh.Parent := pnlLogButtons;
  btnRefresh.SetBounds(8, 6, 80, 28);
  btnRefresh.Caption := rsRefreshLog;
  btnRefresh.OnClick := @RefreshLogClick;

  btnClear := TButton.Create(pnlLogButtons);
  btnClear.Parent := pnlLogButtons;
  btnClear.SetBounds(96, 6, 80, 28);
  btnClear.Caption := rsClearLog;
  btnClear.OnClick := @ClearLogClick;

  lblLogPath := TLabel.Create(pnlLogButtons);
  lblLogPath.Parent := pnlLogButtons;
  lblLogPath.Left := 190;
  lblLogPath.Top := 12;
  lblLogPath.Font.Color := P.TextSecondary;
  lblLogPath.Caption := GetLogPath;

  LogGrid := TStringGrid.Create(TabLog);
  LogGrid.Parent := TabLog;
  LogGrid.Align := alClient;
  LogGrid.FixedRows := 1;
  LogGrid.FixedCols := 0;
  LogGrid.RowCount := 1;
  LogGrid.ColCount := 3;
  LogGrid.Options := LogGrid.Options + [goRowSelect] - [goEditing, goRangeSelect];
  LogGrid.Font.Name := 'Monospace';
  LogGrid.Font.Height := -13;
  LogGrid.Color := P.MemoBg;
  LogGrid.FixedColor := P.PrimaryLight;
  LogGrid.Cells[0, 0] := 'Time';
  LogGrid.Cells[1, 0] := 'Level';
  LogGrid.Cells[2, 0] := 'Message';
  LogGrid.ColWidths[0] := 100;
  LogGrid.ColWidths[1] := 60;
  LogGrid.ColWidths[2] := 600;
  LogGrid.OnPrepareCanvas := @LogGridPrepareCanvas;

  LoadLogFile;

  { ---- Chunk Comparison Tab ---- }
  TabChunk := TTabSheet.Create(Pages);
  TabChunk.PageControl := Pages;
  TabChunk.Caption := rsTabChunkCompare;

  pnlChunkTop := TPanel.Create(TabChunk);
  pnlChunkTop.Parent := TabChunk;
  pnlChunkTop.Align := alTop;
  pnlChunkTop.Height := 56;
  pnlChunkTop.BevelOuter := bvNone;
  pnlChunkTop.Color := P.PanelBg;

  lblChunkInfo := TLabel.Create(pnlChunkTop);
  lblChunkInfo.Parent := pnlChunkTop;
  lblChunkInfo.Left := 8;
  lblChunkInfo.Top := 6;
  lblChunkInfo.Font.Color := P.TextSecondary;
  lblChunkInfo.Caption := rsCompareIntro;

  btnRunCompare := TButton.Create(pnlChunkTop);
  btnRunCompare.Parent := pnlChunkTop;
  btnRunCompare.SetBounds(8, 26, 130, 28);
  btnRunCompare.Caption := rsRunComparison;
  btnRunCompare.OnClick := @RunCompareClick;

  lblStatus := TLabel.Create(pnlChunkTop);
  lblStatus.Parent := pnlChunkTop;
  lblStatus.Left := 150;
  lblStatus.Top := 32;
  lblStatus.Font.Color := P.TextSecondary;
  lblStatus.Caption := '';

  ChunkGrid := TStringGrid.Create(TabChunk);
  ChunkGrid.Parent := TabChunk;
  ChunkGrid.Align := alClient;
  ChunkGrid.FixedRows := 1;
  ChunkGrid.FixedCols := 0;
  ChunkGrid.RowCount := 1;
  ChunkGrid.ColCount := 5;
  ChunkGrid.Options := ChunkGrid.Options + [goRowSelect] - [goEditing, goRangeSelect];
  ChunkGrid.Font.Height := -14;
  ChunkGrid.Color := P.MemoBg;
  ChunkGrid.FixedColor := P.PrimaryLight;
  ChunkGrid.Cells[0, 0] := 'Source';
  ChunkGrid.Cells[1, 0] := 'Book';
  ChunkGrid.Cells[2, 0] := 'Status';
  ChunkGrid.Cells[3, 0] := 'Chapters Affected';
  ChunkGrid.Cells[4, 0] := 'Details';
  ChunkGrid.ColWidths[0] := 160;
  ChunkGrid.ColWidths[1] := 80;
  ChunkGrid.ColWidths[2] := 80;
  ChunkGrid.ColWidths[3] := 140;
  ChunkGrid.ColWidths[4] := 340;
  ChunkGrid.OnPrepareCanvas := @ChunkGridPrepareCanvas;
end;

procedure TDevToolsWindow.LogGridPrepareCanvas(Sender: TObject;
  aCol, aRow: Integer; aState: TGridDrawState);
var
  Level: string;
begin
  if (aRow < 1) or (gdSelected in aState) then
    Exit;
  Level := LogGrid.Cells[1, aRow];
  if Level = 'ERROR' then
    LogGrid.Canvas.Font.Color := clRed
  else if Level = 'WARN' then
    LogGrid.Canvas.Font.Color := $0000A0  { dark orange/brown }
  else if Level = 'DEBUG' then
    LogGrid.Canvas.Font.Color := clGray
  else
    LogGrid.Canvas.Font.Color := clDefault;
end;

procedure TDevToolsWindow.ChunkGridPrepareCanvas(Sender: TObject;
  aCol, aRow: Integer; aState: TGridDrawState);
var
  Status: string;
begin
  if (aRow < 1) or (gdSelected in aState) then
    Exit;
  Status := ChunkGrid.Cells[2, aRow];
  if Status = 'Different' then
    ChunkGrid.Canvas.Font.Color := $0000CC  { red-ish }
  else if Status = 'Match' then
    ChunkGrid.Canvas.Font.Color := $00008000;  { dark green }
end;

procedure TDevToolsWindow.LoadLogFile;
var
  LogPath: string;
  SL: TStringList;
  I, Row: Integer;
  Line, TimeStr, LevelStr, MsgStr: string;
  BracketOpen, BracketClose: Integer;
begin
  LogPath := GetLogPath;
  LogGrid.RowCount := 1;
  if (LogPath = '') or not FileExists(LogPath) then
    Exit;

  SL := TStringList.Create;
  try
    SL.LoadFromFile(LogPath);
    LogGrid.BeginUpdate;
    try
      for I := 0 to SL.Count - 1 do
      begin
        Line := SL[I];
        if Line = '' then
          Continue;

        { Parse: "hh:nn:ss.zzz [LEVEL] message" or "--- Log opened/closed ---" }
        BracketOpen := Pos('[', Line);
        BracketClose := Pos(']', Line);
        if (BracketOpen > 0) and (BracketClose > BracketOpen) then
        begin
          TimeStr := Trim(Copy(Line, 1, BracketOpen - 1));
          LevelStr := Copy(Line, BracketOpen + 1, BracketClose - BracketOpen - 1);
          MsgStr := Trim(Copy(Line, BracketClose + 1, MaxInt));
        end
        else
        begin
          TimeStr := '';
          LevelStr := '';
          MsgStr := Line;
        end;

        Row := LogGrid.RowCount;
        LogGrid.RowCount := Row + 1;
        LogGrid.Cells[0, Row] := TimeStr;
        LogGrid.Cells[1, Row] := LevelStr;
        LogGrid.Cells[2, Row] := MsgStr;
      end;
    finally
      LogGrid.EndUpdate;
    end;

    { Scroll to bottom }
    if LogGrid.RowCount > 1 then
      LogGrid.TopRow := LogGrid.RowCount - 1;
  finally
    SL.Free;
  end;
end;

procedure TDevToolsWindow.RefreshLogClick(Sender: TObject);
begin
  LoadLogFile;
end;

procedure TDevToolsWindow.ClearLogClick(Sender: TObject);
var
  LogPath: string;
  F: TextFile;
begin
  LogPath := GetLogPath;
  if (LogPath = '') or not FileExists(LogPath) then
    Exit;
  AssignFile(F, LogPath);
  try
    Rewrite(F);
    CloseFile(F);
  except
  end;
  LogGrid.RowCount := 1;
end;

procedure TDevToolsWindow.RunCompareClick(Sender: TObject);
begin
  btnRunCompare.Enabled := False;
  btnRunCompare.Caption := rsComparing;
  lblStatus.Caption := '';
  ChunkGrid.RowCount := 1;
  Application.ProcessMessages;
  try
    DoChunkComparison;
  finally
    btnRunCompare.Caption := rsRunComparison;
    btnRunCompare.Enabled := True;
  end;
end;

procedure TDevToolsWindow.DoChunkComparison;
var
  LibPath: string;
  SR: TSearchRec;
  DirName, LangCode, BookCode, ResType: string;
  Parts: TStringArray;
  EnglishULBBooks: TStringList;
  OtherSources: TStringList;
  I, J, K, Row, DiffCount, MatchCount, TotalCompared: Integer;
  EnBook, OtherBook: TBook;
  DiffLines: TStringList;
  ContentDir, EnContentDir: string;
  OtherSlug, OtherBookCode, OtherResType: string;
  OtherParts: TStringArray;
  ChaptersAffected, DetailSummary, Line: string;
  Rows: TChunkCompareRowArray;
  RowCount: Integer;
  TmpRow: TChunkCompareRow;
begin
  LibPath := GetLibraryPath;
  if not DirectoryExists(LibPath) then
  begin
    lblStatus.Caption := rsNoEnglishULB;
    Exit;
  end;

  EnglishULBBooks := TStringList.Create;
  OtherSources := TStringList.Create;
  SetLength(Rows, 0);
  RowCount := 0;
  try
    if FindFirst(LibPath + '*', faDirectory, SR) = 0 then
    begin
      repeat
        DirName := SR.Name;
        if (DirName = '.') or (DirName = '..') then
          Continue;
        if not DirectoryExists(LibPath + DirName + DirectorySeparator +
          'content') then
          Continue;

        Parts := DirName.Split(['_']);
        if Length(Parts) < 3 then
          Continue;

        LangCode := Parts[0];
        BookCode := Parts[1];
        ResType := Parts[2];

        if (ResType = 'tn') or (ResType = 'tq') or (ResType = 'tw') then
          Continue;

        if (LangCode = 'en') and (ResType = 'ulb') then
          EnglishULBBooks.Values[BookCode] := LibPath + DirName +
            DirectorySeparator + 'content'
        else
          OtherSources.Values[DirName] := LibPath + DirName +
            DirectorySeparator + 'content';
      until FindNext(SR) <> 0;
      FindClose(SR);
    end;

    if EnglishULBBooks.Count = 0 then
    begin
      lblStatus.Caption := rsNoEnglishULB;
      Exit;
    end;

    DiffCount := 0;
    MatchCount := 0;
    TotalCompared := 0;

    for I := 0 to OtherSources.Count - 1 do
    begin
      OtherSlug := OtherSources.Names[I];
      ContentDir := OtherSources.ValueFromIndex[I];

      OtherParts := OtherSlug.Split(['_']);
      if Length(OtherParts) < 3 then
        Continue;

      OtherBookCode := OtherParts[1];
      OtherResType := OtherParts[2];

      EnContentDir := EnglishULBBooks.Values[OtherBookCode];
      if EnContentDir = '' then
        Continue;

      Inc(TotalCompared);

      EnBook := TBook.Create(OtherBookCode, 'ulb');
      OtherBook := TBook.Create(OtherBookCode, OtherResType);
      try
        EnBook.LoadFromToc(EnContentDir);
        OtherBook.LoadFromToc(ContentDir);

        DiffLines := EnBook.CompareWith(OtherBook);
        try
          { Grow array }
          if RowCount >= Length(Rows) then
            SetLength(Rows, Length(Rows) + 64);

          Rows[RowCount].Source := OtherSlug;
          Rows[RowCount].BookCode := OtherBookCode;
          Rows[RowCount].BookIndex := BookSortIndex(OtherBookCode);

          if (DiffLines.Count = 1) and
             (Pos('No differences', DiffLines[0]) > 0) then
          begin
            Inc(MatchCount);
            Rows[RowCount].Status := 'Match';
            Rows[RowCount].ChaptersAffected := '';
            Rows[RowCount].Details := 'Identical chunk boundaries';
          end
          else
          begin
            Inc(DiffCount);
            ChaptersAffected := '';
            DetailSummary := '';
            for J := 0 to DiffLines.Count - 1 do
            begin
              Line := Trim(DiffLines[J]);
              if Line = '' then
                Continue;
              if Pos('Chapter missing', Line) > 0 then
              begin
                if ChaptersAffected <> '' then
                  ChaptersAffected := ChaptersAffected + ', ';
                ChaptersAffected := ChaptersAffected +
                  Copy(Line, Pos(':', Line) + 2, MaxInt);
                if DetailSummary <> '' then
                  DetailSummary := DetailSummary + '; ';
                DetailSummary := DetailSummary + Line;
              end
              else if Pos('Chapter ', Line) > 0 then
              begin
                if ChaptersAffected <> '' then
                  ChaptersAffected := ChaptersAffected + ', ';
                ChaptersAffected := ChaptersAffected +
                  Trim(StringReplace(
                    StringReplace(Line, 'Chapter ', '', []),
                    ':', '', []));
              end
              else if (Pos('- ', Line) > 0) or (Pos('! ', Line) > 0) then
              begin
                if DetailSummary <> '' then
                  DetailSummary := DetailSummary + '; ';
                DetailSummary := DetailSummary + Line;
              end;
            end;
            Rows[RowCount].Status := 'Different';
            Rows[RowCount].ChaptersAffected := ChaptersAffected;
            Rows[RowCount].Details := DetailSummary;
          end;
          Inc(RowCount);
        finally
          DiffLines.Free;
        end;
      finally
        EnBook.Free;
        OtherBook.Free;
      end;
    end;

    { Sort by Bible book order, then by source name }
    SetLength(Rows, RowCount);
    for I := 0 to RowCount - 2 do
      for J := I + 1 to RowCount - 1 do
      begin
        if (Rows[J].BookIndex < Rows[I].BookIndex) or
           ((Rows[J].BookIndex = Rows[I].BookIndex) and
            (CompareText(Rows[J].Source, Rows[I].Source) < 0)) then
        begin
          TmpRow := Rows[I];
          Rows[I] := Rows[J];
          Rows[J] := TmpRow;
        end;
      end;

    { Populate grid }
    ChunkGrid.BeginUpdate;
    try
      ChunkGrid.RowCount := 1 + RowCount;
      for I := 0 to RowCount - 1 do
      begin
        Row := I + 1;
        ChunkGrid.Cells[0, Row] := Rows[I].Source;
        ChunkGrid.Cells[1, Row] := UpperCase(Rows[I].BookCode);
        ChunkGrid.Cells[2, Row] := Rows[I].Status;
        ChunkGrid.Cells[3, Row] := Rows[I].ChaptersAffected;
        ChunkGrid.Cells[4, Row] := Rows[I].Details;
      end;
    finally
      ChunkGrid.EndUpdate;
    end;

    lblStatus.Caption := Format('Compared %d sources: %d match, %d different',
      [TotalCompared, MatchCount, DiffCount]);
  finally
    EnglishULBBooks.Free;
    OtherSources.Free;
  end;
end;

procedure ShowDevToolsWindow;
var
  F: TDevToolsWindow;
begin
  F := TDevToolsWindow.CreateWindow(nil);
  try
    F.ShowModal;
  finally
    F.Free;
  end;
end;

end.
