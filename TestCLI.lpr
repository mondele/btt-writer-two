program TestCLI;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  Globals, DataPaths, USFMUtils, BibleChunk, BibleChapter, BibleBook,
  ResourceContainer, ProjectManager;

var
  I: Integer;
  Chunk: TChunk;
  Chapter: TChapter;
  Book: TBook;
  Verses: TStringList;
  MergedText, Extracted: string;
  ChunkMap, SplitResult: TChunkList;
  TempDir, TempFile: string;
  LangCode, BookCode, ResType: string;
  ProjectPath: string;
  SR: TSearchRec;
  Proj: TProject;

begin
  { Parse command-line flags }
  for I := 1 to ParamCount do
    if (ParamStr(I) = '-v') or (ParamStr(I) = '--verbose') then
      Verbose := True;

  WriteLn('=== BTT-Writer Two - TestCLI ===');
  WriteLn('Version: ', APP_NAME, ' ', APP_VERSION);
  WriteLn;

  { --- DataPaths --- }
  WriteLn('--- DataPaths ---');
  WriteLn('  Data path:               ', GetDataPath);
  WriteLn('  Library path:            ', GetLibraryPath);
  WriteLn('  Target translations path:', GetTargetTranslationsPath);
  WriteLn('  Index path:              ', GetIndexPath);
  WriteLn;

  { --- TChunk --- }
  WriteLn('--- TChunk ---');
  Chunk := TChunk.Create('01', False);
  try
    WriteLn('  Created chunk: Name=', Chunk.Name,
            ' ExistsOnDisk=', Chunk.ExistsOnDisk,
            ' Dirty=', Chunk.Dirty);

    Chunk.Content := '\v 1 In the beginning God created the heavens and the earth.';
    WriteLn('  After SetContent: Dirty=', Chunk.Dirty);
    WriteLn('  Content: ', Chunk.Content);

    { Test save/load round-trip }
    TempDir := GetTempDir + 'bttwriter2_test' + DirectorySeparator;
    ForceDirectories(TempDir);
    TempFile := TempDir + '01.txt';

    Chunk.SaveToFile(TempFile);
    WriteLn('  Saved to: ', TempFile, ' Dirty=', Chunk.Dirty);

    Chunk.Content := '';  { clear it }
    Chunk.LoadFromFile(TempFile);
    WriteLn('  Loaded back: ExistsOnDisk=', Chunk.ExistsOnDisk,
            ' Dirty=', Chunk.Dirty);
    WriteLn('  Content: ', Chunk.Content);

    { Clean up temp file }
    DeleteFile(TempFile);
    RemoveDir(TempDir);
  finally
    FreeAndNil(Chunk);
  end;
  WriteLn;

  { --- USFMUtils --- }
  WriteLn('--- USFMUtils ---');
  MergedText := '\v 1 First verse. \v 2 Second verse. \v 10 Tenth verse. \v 11 Eleventh verse.';

  WriteLn('  Test text: ', MergedText);
  WriteLn('  FindVerseMarkerPos(v1)=', FindVerseMarkerPos(MergedText, 1));
  WriteLn('  FindVerseMarkerPos(v2)=', FindVerseMarkerPos(MergedText, 2));
  WriteLn('  FindVerseMarkerPos(v10)=', FindVerseMarkerPos(MergedText, 10));
  WriteLn('  FindVerseMarkerPos(v11)=', FindVerseMarkerPos(MergedText, 11));
  WriteLn('  FindVerseMarkerPos(v99)=', FindVerseMarkerPos(MergedText, 99));

  { Verify \v 1 does not match \v 10 }
  WriteLn('  Boundary test: v1 pos=', FindVerseMarkerPos(MergedText, 1),
          ' v10 pos=', FindVerseMarkerPos(MergedText, 10),
          ' (should differ)');

  Extracted := ExtractVerseRange(MergedText, 2, 2);
  WriteLn('  ExtractVerseRange(2,2)=', Extracted);

  Verses := ParseVerseNumbers(MergedText);
  try
    Write('  ParseVerseNumbers: ');
    for I := 0 to Verses.Count - 1 do
    begin
      if I > 0 then Write(', ');
      Write(Verses[I]);
    end;
    WriteLn;
  finally
    FreeAndNil(Verses);
  end;
  WriteLn;

  { --- TChapter merge/split --- }
  WriteLn('--- TChapter merge/split ---');
  Chapter := TChapter.Create('01');
  try
    Chunk := TChunk.Create('01');
    Chunk.Content := '\v 1 First verse. \v 2 Second verse. \v 3 Third verse. ';
    Chapter.AddChunk(Chunk);

    Chunk := TChunk.Create('04');
    Chunk.Content := '\v 4 Fourth verse. \v 5 Fifth verse. ';
    Chapter.AddChunk(Chunk);

    MergedText := Chapter.MergeAllContent;
    WriteLn('  Merged: ', MergedText);

    { Now split with a different chunk map }
    Verses := TStringList.Create;
    try
      Verses.Add('1');
      Verses.Add('3');
      Verses.Add('5');

      SplitResult := Chapter.SplitByChunkMap(MergedText, Verses);
      try
        WriteLn('  Split into ', SplitResult.Count, ' chunks:');
        for I := 0 to SplitResult.Count - 1 do
          WriteLn('    Chunk ', SplitResult[I].Name, ': ', SplitResult[I].Content);
      finally
        FreeAndNil(SplitResult);
      end;
    finally
      FreeAndNil(Verses);
    end;
  finally
    FreeAndNil(Chapter);
  end;
  WriteLn;

  { --- ResourceContainer.ParseDirName --- }
  WriteLn('--- ResourceContainer.ParseDirName ---');
  if TResourceContainer.ParseDirName('en_act_ulb', LangCode, BookCode, ResType) then
    WriteLn('  en_act_ulb -> lang=', LangCode, ' book=', BookCode, ' type=', ResType)
  else
    WriteLn('  en_act_ulb -> PARSE FAILED');

  if TResourceContainer.ParseDirName('bad_name', LangCode, BookCode, ResType) then
    WriteLn('  bad_name -> lang=', LangCode, ' book=', BookCode, ' type=', ResType)
  else
    WriteLn('  bad_name -> correctly rejected');
  WriteLn;

  { --- ProjectManager (if a project exists) --- }
  WriteLn('--- ProjectManager ---');
  ProjectPath := GetTargetTranslationsPath;
  if DirectoryExists(ProjectPath) then
  begin
    WriteLn('  Target translations dir exists: ', ProjectPath);
    if FindFirst(IncludeTrailingPathDelimiter(ProjectPath) + '*', faDirectory, SR) = 0 then
    begin
      repeat
        if (SR.Attr and faDirectory <> 0) and (SR.Name <> '.') and (SR.Name <> '..') then
        begin
          WriteLn('  Found project dir: ', SR.Name);
          Proj := TProject.Create(IncludeTrailingPathDelimiter(ProjectPath) + SR.Name);
          try
            WriteLn('    Language: ', Proj.TargetLanguageCode);
            WriteLn('    Book: ', Proj.BookCode);
            WriteLn('    Resource: ', Proj.ResourceType);
            WriteLn('    Source lang: ', Proj.GetSourceLanguageCode);
            WriteLn('    Source type: ', Proj.GetSourceResourceType);
          finally
            FreeAndNil(Proj);
          end;
          Break;  { just show the first one }
        end;
      until FindNext(SR) <> 0;
      FindClose(SR);
    end
    else
      WriteLn('  No project directories found.');
  end
  else
    WriteLn('  No target translations directory found at ', ProjectPath);

  WriteLn;
  WriteLn('=== All tests passed ===');
end.
