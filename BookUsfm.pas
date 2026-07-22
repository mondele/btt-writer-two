unit BookUsfm;

{$mode objfpc}{$H+}

{ Monolithic-USFM project storage.

  Canonical file lives at
      <projectdir>/.usfm/<NN>-<CODE>_<lngcode>.usfm
  where <NN> is the Paratext book number (OT 01-39, NT 41-67), <CODE>
  is the uppercase USFM book code, and <lngcode> is the target language
  code from the manifest. Whole-book USFM is the industry-standard
  exchange format (Paratext, USFM ecosystem); per-write disk cost at
  Bible-book scale is irrelevant.

  Phase 1 surface: filename helper, load, save, default header builder.
  Phase 1 stores each chapter's USFM body as a single TChunk on
  TChapter (chunk name = chapter ID). Subsequent phases route the
  chapter body through the existing source-chunk splitter for display
  and back through the ULB splitter on save. }

interface

uses
  Classes, SysUtils, BibleBook, BibleChapter, BibleChunk, BookCodes;

type
  { USFM book-level header data. Set from manifest values when building
    a fresh monolithic file; preserved verbatim when round-tripping an
    existing file. }
  TUSFMBookHeader = record
    BookID: string;       { \id   — required, 3-char uppercase USFM code }
    Encoding: string;     { \ide  — defaults to UTF-8 }
    BookName: string;     { \h    — running header }
    TocLong: string;      { \toc1 — long table-of-contents entry }
    TocShort: string;     { \toc2 — short table-of-contents entry }
    TocAbbrev: string;    { \toc3 — abbreviation }
    MainTitle: string;    { \mt   — main title rendered at top of book }
  end;

{ Build the canonical filesystem path for the monolithic USFM file.
  ProjectDir may or may not have a trailing path delimiter. Returns ''
  if BookCode is not recognized. }
function MonolithicUSFMPath(const ProjectDir, BookCode, LangCode: string): string;

{ Read a monolithic USFM file into ABook + AHeader.

  - ABook is reset: existing chapters are released, then chapters from
    the file are appended in document order. Each chapter holds one
    TChunk named after the chapter ID (e.g. '01'); the chunk's Content
    is the verbatim USFM body for that chapter, starting from after the
    '\c <n>' marker.
  - AHeader receives \id / \ide / \h / \toc1-3 / \mt values found in the
    file. Missing fields are left blank.
  - Returns False if APath does not exist or cannot be read. ABook is
    left untouched on failure. }
function LoadMonolithicUSFM(const APath: string; ABook: TBook;
  out AHeader: TUSFMBookHeader): Boolean;

{ Write ABook + AHeader as a monolithic USFM file at APath.

  - Creates the containing directory if needed.
  - Emits header markers in canonical order: \id \ide \h \toc1 \toc2
    \toc3 \mt, omitting any field whose value is empty.
  - For each chapter, emits '\c <id>\n' followed by the chapter's chunk
    contents in order. Newlines between chunks are normalized to '\n'. }
procedure SaveMonolithicUSFM(const APath: string; ABook: TBook;
  const AHeader: TUSFMBookHeader);

{ Build a default header populated from book code + display name. Caller
  can override individual fields before save. }
function DefaultUSFMHeader(const BookCode, DisplayName: string): TUSFMBookHeader;

{ Collapse whitespace runs (space, tab, CR, LF) to single spaces and trim.
  Lets monolithic and chunk-derived chapter text compare equal despite
  line-ending and layout differences. }
function NormalizeUSFMWhitespace(const S: string): string;

{ Phase 4 verification: compare a monolithic-loaded book against a book
  built from per-chunk files. Only chapters with numeric IDs participate
  (front matter is not stored in the monolithic body); a chapter missing
  on one side compares as empty text. Returns one line per diverging
  chapter; empty list means the books agree. Caller frees the result. }
function DiffMonolithicAgainstChunks(MonoBook, ChunkBook: TBook): TStringList;

implementation

uses
  USFMUtils;

function PaddedBookNumber(const BookCode: string): string;
var
  N: Integer;
begin
  N := USFMBookNumber(BookCode);
  if N = 0 then
    Result := ''
  else if N < 10 then
    Result := '0' + IntToStr(N)
  else
    Result := IntToStr(N);
end;

function MonolithicUSFMPath(const ProjectDir, BookCode, LangCode: string): string;
var
  NN, Code: string;
begin
  Result := '';
  NN := PaddedBookNumber(BookCode);
  Code := USFMBookCodeUpper(BookCode);
  if (NN = '') or (Code = '') then Exit;
  Result := IncludeTrailingPathDelimiter(ProjectDir) + '.usfm' +
            DirectorySeparator + NN + '-' + Code + '_' + Trim(LangCode) +
            '.usfm';
end;

function DefaultUSFMHeader(const BookCode, DisplayName: string): TUSFMBookHeader;
var
  Code: string;
begin
  Code := USFMBookCodeUpper(BookCode);
  Result.BookID    := Code;
  Result.Encoding  := 'UTF-8';
  Result.BookName  := DisplayName;
  Result.TocLong   := DisplayName;
  Result.TocShort  := DisplayName;
  Result.TocAbbrev := DisplayName;
  Result.MainTitle := DisplayName;
end;

{ ---- Verification ---- }

function NormalizeUSFMWhitespace(const S: string): string;
var
  SrcI, DstI: Integer;
  PendingSpace: Boolean;
begin
  SetLength(Result, Length(S));
  DstI := 0;
  PendingSpace := False;
  for SrcI := 1 to Length(S) do
    case S[SrcI] of
      ' ', #9, #10, #13:
        PendingSpace := True;
      else
      begin
        if PendingSpace and (DstI > 0) then
        begin
          Inc(DstI);
          Result[DstI] := ' ';
        end;
        PendingSpace := False;
        Inc(DstI);
        Result[DstI] := S[SrcI];
      end;
    end;
  SetLength(Result, DstI);
end;

function DiffMonolithicAgainstChunks(MonoBook, ChunkBook: TBook): TStringList;
var
  Diffs: TStringList;
  Seen: TStringList;

  function NormalizedChapter(Book: TBook; const ID: string): string;
  var
    C: TChapter;
  begin
    Result := '';
    if Book = nil then Exit;
    C := Book.GetChapter(ID);
    { '\c' markers are owned by the monolithic file and embedded in v1
      chunk files — strip them on both sides so the comparison sees only
      the actual text. }
    if C <> nil then
      Result := NormalizeUSFMWhitespace(StripChapterMarkers(C.MergeAllContent));
  end;

  function FirstDivergence(const A, B: string): Integer;
  var
    I, L: Integer;
  begin
    L := Length(A);
    if Length(B) < L then L := Length(B);
    for I := 1 to L do
      if A[I] <> B[I] then Exit(I);
    Result := L + 1;
  end;

  procedure CompareChapterID(const ID: string);
  var
    MonoText, ChunkText: string;
    DivPos: Integer;
  begin
    if Seen.IndexOf(ID) >= 0 then Exit;
    Seen.Add(ID);
    MonoText := NormalizedChapter(MonoBook, ID);
    ChunkText := NormalizedChapter(ChunkBook, ID);
    if MonoText = ChunkText then Exit;
    DivPos := FirstDivergence(MonoText, ChunkText);
    Diffs.Add(Format(
      'chapter %s diverges at offset %d: monolithic %d chars "%s", ' +
      'chunks %d chars "%s"',
      [ID, DivPos,
       Length(MonoText), Copy(MonoText, DivPos, 24),
       Length(ChunkText), Copy(ChunkText, DivPos, 24)]));
  end;

  procedure CompareBookChapters(Book: TBook);
  var
    I, N: Integer;
  begin
    if Book = nil then Exit;
    for I := 0 to Book.Chapters.Count - 1 do
      if TryStrToInt(Book.Chapters[I].ID, N) then
        CompareChapterID(Book.Chapters[I].ID);
  end;

begin
  Diffs := TStringList.Create;
  Seen := TStringList.Create;
  try
    CompareBookChapters(MonoBook);
    CompareBookChapters(ChunkBook);
  finally
    FreeAndNil(Seen);
  end;
  Result := Diffs;
end;

{ ---- Loading ---- }

{ Strip leading marker token from a USFM line and return the rest.
  Given input that starts at the position of the backslash, returns
  whatever follows the marker name and any single delimiting space. }
function MarkerValue(const Line, Marker: string): string;
var
  Prefix: string;
begin
  Result := '';
  Prefix := '\' + Marker;
  if not Line.StartsWith(Prefix) then Exit;
  if Length(Line) = Length(Prefix) then Exit;
  Result := Trim(Copy(Line, Length(Prefix) + 1, Length(Line)));
end;

function StartsWithMarker(const Line, Marker: string): Boolean;
var
  Prefix: string;
begin
  Prefix := '\' + Marker;
  Result := Line.StartsWith(Prefix) and
            ((Length(Line) = Length(Prefix)) or
             (Line[Length(Prefix) + 1] = ' ') or
             (Line[Length(Prefix) + 1] = #9));
end;

function LoadMonolithicUSFM(const APath: string; ABook: TBook;
  out AHeader: TUSFMBookHeader): Boolean;
var
  Lines: TStringList;
  Body: TStringList;
  I: Integer;
  Line: string;
  CurChapterID: string;
  PendingChapter: TChapter;

  procedure FlushChapter;
  var
    Chunk: TChunk;
  begin
    if PendingChapter = nil then Exit;
    Chunk := TChunk.Create(PendingChapter.ID);
    Chunk.Content := Body.Text;
    PendingChapter.AddChunk(Chunk);
    ABook.AddChapter(PendingChapter);
    PendingChapter := nil;
    Body.Clear;
  end;

begin
  Result := False;
  AHeader := Default(TUSFMBookHeader);
  AHeader.Encoding := 'UTF-8';

  if not FileExists(APath) then Exit;

  Lines := TStringList.Create;
  Body := TStringList.Create;
  PendingChapter := nil;
  try
    try
      Lines.LoadFromFile(APath);
    except
      Exit;
    end;

    ABook.Chapters.Clear;

    for I := 0 to Lines.Count - 1 do
    begin
      Line := Lines[I];

      if StartsWithMarker(Line, 'id') then
        AHeader.BookID := MarkerValue(Line, 'id')
      else if StartsWithMarker(Line, 'ide') then
        AHeader.Encoding := MarkerValue(Line, 'ide')
      else if StartsWithMarker(Line, 'h') then
        AHeader.BookName := MarkerValue(Line, 'h')
      else if StartsWithMarker(Line, 'toc1') then
        AHeader.TocLong := MarkerValue(Line, 'toc1')
      else if StartsWithMarker(Line, 'toc2') then
        AHeader.TocShort := MarkerValue(Line, 'toc2')
      else if StartsWithMarker(Line, 'toc3') then
        AHeader.TocAbbrev := MarkerValue(Line, 'toc3')
      else if StartsWithMarker(Line, 'mt') then
        AHeader.MainTitle := MarkerValue(Line, 'mt')
      else if StartsWithMarker(Line, 'c') then
      begin
        CurChapterID := MarkerValue(Line, 'c');
        if CurChapterID = '' then Continue;
        { Pad to 2-digit chapter ID to match the chunk-dir naming. }
        if (Length(CurChapterID) = 1) and (CurChapterID[1] in ['0'..'9']) then
          CurChapterID := '0' + CurChapterID;
        { A repeated '\c' for the chapter that is already open is an
          embedded marker from a v1 chunk body (written by builds that
          predate StripChapterMarkers) — ignore it and keep accumulating
          instead of splitting the chapter in two. }
        if (PendingChapter <> nil) and (PendingChapter.ID = CurChapterID) then
          Continue;
        FlushChapter;
        PendingChapter := TChapter.Create(CurChapterID);
      end
      else if PendingChapter <> nil then
        Body.Add(Line);
    end;

    FlushChapter;
    Result := True;
  finally
    FreeAndNil(Lines);
    FreeAndNil(Body);
    if PendingChapter <> nil then
      FreeAndNil(PendingChapter);
  end;
end;

{ ---- Saving ---- }

procedure AppendHeaderLine(SL: TStringList; const Marker, Value: string);
begin
  if Trim(Value) = '' then Exit;
  SL.Add('\' + Marker + ' ' + Value);
end;

procedure SaveMonolithicUSFM(const APath: string; ABook: TBook;
  const AHeader: TUSFMBookHeader);
var
  Out_: TStringList;
  Dir: string;
  I: Integer;
  Chapter: TChapter;
  ChapNum: Integer;
  ChapterBody: string;
begin
  Dir := ExtractFilePath(APath);
  if (Dir <> '') and not DirectoryExists(Dir) then
    ForceDirectories(Dir);

  Out_ := TStringList.Create;
  try
    AppendHeaderLine(Out_, 'id',   AHeader.BookID);
    AppendHeaderLine(Out_, 'ide',  AHeader.Encoding);
    AppendHeaderLine(Out_, 'h',    AHeader.BookName);
    AppendHeaderLine(Out_, 'toc1', AHeader.TocLong);
    AppendHeaderLine(Out_, 'toc2', AHeader.TocShort);
    AppendHeaderLine(Out_, 'toc3', AHeader.TocAbbrev);
    AppendHeaderLine(Out_, 'mt',   AHeader.MainTitle);

    for I := 0 to ABook.Chapters.Count - 1 do
    begin
      Chapter := ABook.Chapters[I];
      if not TryStrToInt(Chapter.ID, ChapNum) then Continue;

      Out_.Add('\c ' + IntToStr(ChapNum));

      { v1 chunk files embed '\c <n>' inside the first verse chunk (and
        the chapter label rides as plain text in title chunks). The
        monolithic file owns chapter markers — strip embedded copies or
        reload would split this chapter at the stray marker. }
      ChapterBody := StripChapterMarkers(Chapter.MergeAllContent);
      ChapterBody := Trim(ChapterBody);
      if ChapterBody <> '' then
        Out_.Add(ChapterBody);
    end;

    Out_.SaveToFile(APath);
  finally
    FreeAndNil(Out_);
  end;
end;

end.
