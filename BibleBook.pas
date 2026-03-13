unit BibleBook;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Generics.Collections, BibleChapter, BibleChunk, Globals;

type
  TChapterList = specialize TObjectList<TChapter>;

  TBook = class
  private
    FCode: string;
    FResourceType: string;
    FChapters: TChapterList;
  public
    constructor Create(const ACode, AResType: string);
    destructor Destroy; override;

    function GetChapter(const AID: string): TChapter;
    procedure AddChapter(AChapter: TChapter);

    { Parse toc.yml to build chapter/chunk structure (no content loaded) }
    procedure LoadFromToc(const ContentDir: string);

    { Load actual file content for all chunks }
    procedure LoadContent(const ContentDir, Ext: string);

    { Save all dirty chunks to disk }
    procedure SaveAllDirty(const ContentDir, Ext: string);

    { Compare structure with another book }
    function CompareWith(Other: TBook): TStringList;

    property Code: string read FCode;
    property ResourceType: string read FResourceType;
    property Chapters: TChapterList read FChapters;
  end;

implementation

constructor TBook.Create(const ACode, AResType: string);
begin
  inherited Create;
  FCode := ACode;
  FResourceType := AResType;
  FChapters := TChapterList.Create(True);
end;

destructor TBook.Destroy;
begin
  FreeAndNil(FChapters);
  inherited Destroy;
end;

function TBook.GetChapter(const AID: string): TChapter;
var
  I: Integer;
begin
  for I := 0 to FChapters.Count - 1 do
    if FChapters[I].ID = AID then
      Exit(FChapters[I]);
  Result := nil;
end;

procedure TBook.AddChapter(AChapter: TChapter);
begin
  FChapters.Add(AChapter);
end;

procedure TBook.LoadFromToc(const ContentDir: string);
var
  TocPath: string;
  TocLines: TStringList;
  Line, ChapterID, ChunkID: string;
  CurrentChapter: TChapter;
  I: Integer;

  function IsChapterLine(const S: string): Boolean;
  begin
    Result := Trim(S).StartsWith('chapter:');
  end;

  function ExtractChapterID(const S: string): string;
  var
    P: Integer;
  begin
    P := Pos(':', S);
    if P > 0 then
      Result := Trim(Copy(S, P + 1, Length(S))).Trim([' ', '''', '"'])
    else
      Result := '';
  end;

  function IsChunkListStart(const S: string): Boolean;
  begin
    Result := Trim(S) = 'chunks:';
  end;

  function IsChunkLine(const S: string): Boolean;
  begin
    Result := Trim(S).StartsWith('-');
  end;

  function ExtractChunkID(const S: string): string;
  var
    P: Integer;
  begin
    P := Pos('-', S);
    if P > 0 then
      Result := Trim(Copy(S, P + 1, Length(S))).Trim([' ', '''', '"'])
    else
      Result := '';
  end;

begin
  if Verbose then
    WriteLn('Loading book ', FCode, ' of type ', FResourceType, ' from ', ContentDir);

  TocPath := IncludeTrailingPathDelimiter(ContentDir) + 'toc.yml';
  if not FileExists(TocPath) then
  begin
    WriteLn('Cannot find file ', TocPath);
    Exit;
  end;

  TocLines := TStringList.Create;
  try
    TocLines.LoadFromFile(TocPath);
    CurrentChapter := nil;

    for I := 0 to TocLines.Count - 1 do
    begin
      Line := TocLines[I];

      if IsChapterLine(Line) then
      begin
        ChapterID := ExtractChapterID(Line);
        if ChapterID <> '' then
        begin
          if Verbose then
            WriteLn('  Adding chapter ', ChapterID);
          CurrentChapter := TChapter.Create(ChapterID);
          AddChapter(CurrentChapter);
        end;
      end
      else if IsChunkListStart(Line) then
        Continue
      else if Assigned(CurrentChapter) and IsChunkLine(Line) then
      begin
        ChunkID := ExtractChunkID(Line);
        if ChunkID <> '' then
        begin
          if Verbose then
            WriteLn('    Adding chunk ', ChunkID);
          CurrentChapter.AddChunk(TChunk.Create(ChunkID));
        end;
      end;
    end;
  finally
    FreeAndNil(TocLines);
  end;
end;

procedure TBook.LoadContent(const ContentDir, Ext: string);
var
  I: Integer;
begin
  for I := 0 to FChapters.Count - 1 do
  begin
    FChapters[I].LoadChunkFiles(ContentDir, Ext);
    { Scan for on-disk chunk files not in the source toc so that content
      stored under different chunk boundaries is not silently dropped. }
    FChapters[I].LoadExtraChunkFiles(ContentDir, Ext);
  end;
end;

procedure TBook.SaveAllDirty(const ContentDir, Ext: string);
var
  I: Integer;
begin
  for I := 0 to FChapters.Count - 1 do
    FChapters[I].SaveDirtyChunks(ContentDir, Ext);
end;

function TBook.CompareWith(Other: TBook): TStringList;
var
  I: Integer;
  ChapterA, ChapterB: TChapter;
  DiffLines: TStringList;
  HasDifferences: Boolean;
begin
  HasDifferences := False;
  Result := TStringList.Create;

  if Other = nil then
  begin
    Result.Add('Other book is missing.');
    Exit;
  end;

  for I := 0 to FChapters.Count - 1 do
  begin
    ChapterA := FChapters[I];
    ChapterB := Other.GetChapter(ChapterA.ID);

    if ChapterB = nil then
    begin
      HasDifferences := True;
      Result.Add('Chapter missing in other: ' + ChapterA.ID);
    end
    else
    begin
      DiffLines := ChapterA.CompareChunks(ChapterB);
      if DiffLines.Count > 0 then
      begin
        HasDifferences := True;
        Result.AddStrings(DiffLines);
      end;
      FreeAndNil(DiffLines);
    end;
  end;

  if not HasDifferences then
    Result.Add('No differences found between ' + FCode + ' (' + FResourceType
               + ') and ' + Other.FCode + ' (' + Other.FResourceType + ').');
end;

end.
