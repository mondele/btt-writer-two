unit BibleChapter;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Generics.Collections, BibleChunk, USFMUtils, Globals;

type
  TChunkList = specialize TObjectList<TChunk>;

  TChapter = class
  private
    FID: string;
    FChunks: TChunkList;
  public
    constructor Create(const AID: string);
    destructor Destroy; override;

    procedure AddChunk(AChunk: TChunk);

    { Concatenate all chunk contents into a single string }
    function MergeAllContent: string;

    { Split merged text into chunks based on a verse-number chunk map.
      ChunkMap is a list of starting verse numbers (as strings).
      Returns a new TChunkList (caller owns it). }
    function SplitByChunkMap(const MergedText: string; ChunkMap: TStringList): TChunkList;

    { Load chunk files from a directory. Looks for files named <chunkName><ext> }
    procedure LoadChunkFiles(const Dir, Ext: string);

    { Scan a chapter directory for any .txt files not already in the chunk list
      and load them (preserves on-disk content that doesn't match the source toc) }
    procedure LoadExtraChunkFiles(const Dir, Ext: string);

    { Save only chunks that have been modified }
    procedure SaveDirtyChunks(const Dir, Ext: string);

    { Compare chunks with another chapter, return list of differences }
    function CompareChunks(Other: TChapter): TStringList;

    property ID: string read FID;
    property Chunks: TChunkList read FChunks;
  end;

implementation

constructor TChapter.Create(const AID: string);
begin
  inherited Create;
  FID := AID;
  FChunks := TChunkList.Create(True);  { owns objects - fixes chunkCounter bug #1 }
end;

destructor TChapter.Destroy;
begin
  FreeAndNil(FChunks);
  inherited Destroy;
end;

procedure TChapter.AddChunk(AChunk: TChunk);
begin
  FChunks.Add(AChunk);
end;

function TChapter.MergeAllContent: string;
var
  I, StartVerse: Integer;
  ChunkText: string;
begin
  Result := '';
  for I := 0 to FChunks.Count - 1 do
  begin
    ChunkText := FChunks[I].Content;

    { Legacy project chunks sometimes have no verse markers. Infer a start
      marker from this chunk filename and an end boundary marker from the
      next chunk filename so splitting stays bounded. }
    if (Pos('\v ', ChunkText) = 0) and TryStrToInt(FChunks[I].Name, StartVerse) then
    begin
      if Verbose then
        WriteLn(Format('[VerseInference] chapter=%s chunk=%s startVerse=%d',
          [FID, FChunks[I].Name, StartVerse]));

      ChunkText := Trim(ChunkText);
      if ChunkText <> '' then
        ChunkText := '\v ' + IntToStr(StartVerse) + ' ' + ChunkText
      else
        ChunkText := '\v ' + IntToStr(StartVerse) + ' ';
    end;

    Result := Result + ChunkText;
  end;
end;

function TChapter.SplitByChunkMap(const MergedText: string; ChunkMap: TStringList): TChunkList;
var
  I, VerseNum, StartPos, EndPos, NextVerse, FallbackPos: Integer;
  ChunkContent: string;
  Chunk: TChunk;
begin
  Result := TChunkList.Create(True);
  FallbackPos := 1;

  if ChunkMap.Count = 0 then
  begin
    { No chunk map - put everything in one chunk }
    Chunk := TChunk.Create('01');
    Chunk.Content := MergedText;
    Result.Add(Chunk);
    Exit;
  end;

  for I := 0 to ChunkMap.Count - 1 do
  begin
    if not TryStrToInt(ChunkMap[I], VerseNum) then
    begin
      { Non-numeric chunk (e.g., 'title'): extract text before first
        USFM marker. This captures title text that precedes \d, \v, etc. }
      EndPos := 1;
      while (EndPos <= Length(MergedText)) and (MergedText[EndPos] <> '\') do
        Inc(EndPos);
      ChunkContent := Trim(Copy(MergedText, 1, EndPos - 1));
      Chunk := TChunk.Create(ChunkMap[I]);
      Chunk.Content := ChunkContent;
      Result.Add(Chunk);
      FallbackPos := EndPos;
      Continue;
    end;

    StartPos := FindVerseMarkerPos(MergedText, VerseNum);
    if StartPos = 0 then
    begin
      { Verse marker missing: keep processing from the current fallback cursor
        instead of dropping text for this chunk. }
      StartPos := FallbackPos;
      while (StartPos <= Length(MergedText)) and
            (MergedText[StartPos] in [' ', #9, #10, #13]) do
        Inc(StartPos);
      if StartPos > Length(MergedText) then
      begin
        Chunk := TChunk.Create(ChunkMap[I]);
        Result.Add(Chunk);
        Continue;
      end;
    end;

    { For verse 1, include any preceding USFM content (like \d)
      that comes after the title text }
    if (VerseNum = 1) and (StartPos > 1) then
    begin
      EndPos := 1;
      while (EndPos < StartPos) and (MergedText[EndPos] <> '\') do
        Inc(EndPos);
      if EndPos < StartPos then
        StartPos := EndPos;
    end;

    { Find end position: start of next chunk's first verse, or end of text }
    if I < ChunkMap.Count - 1 then
    begin
      if TryStrToInt(ChunkMap[I + 1], NextVerse) then
        EndPos := FindVerseMarkerPos(MergedText, NextVerse)
      else
        EndPos := 0;
    end
    else
      EndPos := 0;

    if EndPos > 0 then
      ChunkContent := Copy(MergedText, StartPos, EndPos - StartPos)
    else
      ChunkContent := Copy(MergedText, StartPos, Length(MergedText) - StartPos + 1);

    Chunk := TChunk.Create(ChunkMap[I]);
    Chunk.Content := ChunkContent;
    Result.Add(Chunk);

    if EndPos > 0 then
      FallbackPos := EndPos
    else
      FallbackPos := Length(MergedText) + 1;
  end;
end;

procedure TChapter.LoadChunkFiles(const Dir, Ext: string);
var
  I: Integer;
  FilePath: string;
begin
  for I := 0 to FChunks.Count - 1 do
  begin
    FilePath := IncludeTrailingPathDelimiter(Dir) + FID
                + DirectorySeparator + FChunks[I].Name + Ext;
    FChunks[I].LoadFromFile(FilePath);
  end;
end;

procedure TChapter.LoadExtraChunkFiles(const Dir, Ext: string);
var
  ChapterDir: string;
  SR: TSearchRec;
  ChunkName: string;
  I: Integer;
  Found: Boolean;
  Extra: TChunk;
  InsertPos, ChunkVerse, ExistingVerse: Integer;
begin
  ChapterDir := IncludeTrailingPathDelimiter(Dir) + FID;
  if not DirectoryExists(ChapterDir) then
    Exit;

  if FindFirst(IncludeTrailingPathDelimiter(ChapterDir) + '*' + Ext,
               faAnyFile and not faDirectory, SR) = 0 then
  try
    repeat
      if (SR.Name = '.') or (SR.Name = '..') then
        Continue;
      ChunkName := ChangeFileExt(SR.Name, '');

      { Check if this chunk is already in the list }
      Found := False;
      for I := 0 to FChunks.Count - 1 do
        if FChunks[I].Name = ChunkName then
        begin
          Found := True;
          Break;
        end;

      if not Found then
      begin
        Extra := TChunk.Create(ChunkName);
        Extra.LoadFromFile(IncludeTrailingPathDelimiter(ChapterDir) +
                           ChunkName + Ext);
        { Insert in sorted verse order so MergeAllContent stays sequential }
        if TryStrToInt(ChunkName, ChunkVerse) then
        begin
          InsertPos := FChunks.Count;
          for I := 0 to FChunks.Count - 1 do
            if TryStrToInt(FChunks[I].Name, ExistingVerse) and
               (ExistingVerse > ChunkVerse) then
            begin
              InsertPos := I;
              Break;
            end;
          FChunks.Insert(InsertPos, Extra);
        end
        else
          FChunks.Add(Extra);
      end;
    until FindNext(SR) <> 0;
  finally
    FindClose(SR);
  end;
end;

procedure TChapter.SaveDirtyChunks(const Dir, Ext: string);
var
  I: Integer;
  FilePath: string;
begin
  for I := 0 to FChunks.Count - 1 do
  begin
    if FChunks[I].Dirty then
    begin
      FilePath := IncludeTrailingPathDelimiter(Dir) + FID
                  + DirectorySeparator + FChunks[I].Name + Ext;
      FChunks[I].SaveToFile(FilePath);
    end;
  end;
end;

function TChapter.CompareChunks(Other: TChapter): TStringList;
var
  I, J: Integer;
  ChunkA, ChunkB: TChunk;
  Found: Boolean;
  SeenNames: TStringList;
  HasDifferences: Boolean;
begin
  Result := TStringList.Create;
  HasDifferences := False;

  if Other = nil then
  begin
    Result.Add('  Chapter ' + FID + ':');
    Result.Add('    - Target chapter missing');
    Exit;
  end;

  SeenNames := TStringList.Create;
  try
    for I := 0 to FChunks.Count - 1 do
    begin
      ChunkA := FChunks[I];
      Found := False;
      for J := 0 to Other.Chunks.Count - 1 do
      begin
        ChunkB := Other.Chunks[J];
        if ChunkA.Name = ChunkB.Name then
        begin
          SeenNames.Add(ChunkA.Name);
          Found := True;
          if ChunkA.ExistsOnDisk <> ChunkB.ExistsOnDisk then
          begin
            if not ChunkA.ExistsOnDisk then
              Result.Add('    - ' + ChunkA.Name + ' (missing in source)')
            else if not ChunkB.ExistsOnDisk then
              Result.Add('    - ' + ChunkA.Name + ' (missing in target)')
            else
              Result.Add('    ! ' + ChunkA.Name + ' (OnDisk mismatch)');
            HasDifferences := True;
          end;
          Break;
        end;
      end;
      if not Found then
      begin
        Result.Add('    - ' + ChunkA.Name + ' (missing in target)');
        HasDifferences := True;
      end;
    end;

    for J := 0 to Other.Chunks.Count - 1 do
    begin
      ChunkB := Other.Chunks[J];
      if SeenNames.IndexOf(ChunkB.Name) = -1 then
      begin
        Result.Add('    - ' + ChunkB.Name + ' (extra in target)');
        HasDifferences := True;
      end;
    end;
  finally
    FreeAndNil(SeenNames);
  end;

  if HasDifferences then
    Result.Insert(0, '  Chapter ' + FID + ':')
  else
    Result.Clear;
end;

end.
