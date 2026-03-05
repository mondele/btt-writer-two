program TestCLI;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, fpjson, jsonparser,
  Globals, DataPaths, USFMUtils, BibleChunk, BibleChapter, BibleBook,
  ResourceContainer, ProjectManager, TStudioPackage;

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
  PkgInfo: TTStudioPackageInfo;
  ExtractedManifestData: TJSONData;
  ExtractedManifestText: string;
  FailCount: Integer;

procedure AssertTrue(const Msg: string; Cond: Boolean);
begin
  if Cond then
    WriteLn('  [PASS] ', Msg)
  else
  begin
    WriteLn('  [FAIL] ', Msg);
    Inc(FailCount);
  end;
end;

procedure AssertFileExists(const Msg, APath: string);
begin
  AssertTrue(Msg + ' exists: ' + APath, FileExists(APath));
end;

procedure AssertEqInt(const Msg: string; Expected, Actual: Integer);
begin
  AssertTrue(Format('%s (expected=%d actual=%d)', [Msg, Expected, Actual]),
    Expected = Actual);
end;

procedure AssertContains(const Msg, SubStr, S: string);
begin
  AssertTrue(Msg + ' contains "' + SubStr + '"', Pos(SubStr, S) > 0);
end;

begin
  FailCount := 0;
  Randomize;
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
  AssertTrue('Find v1 in standard text', FindVerseMarkerPos(MergedText, 1) > 0);
  AssertTrue('Find v10 in standard text', FindVerseMarkerPos(MergedText, 10) > 0);
  AssertEqInt('Missing verse returns 0', 0, FindVerseMarkerPos(MergedText, 99));

  { Verify \v 1 does not match \v 10 }
  WriteLn('  Boundary test: v1 pos=', FindVerseMarkerPos(MergedText, 1),
          ' v10 pos=', FindVerseMarkerPos(MergedText, 10),
          ' (should differ)');
  AssertTrue('v1 and v10 are distinct markers',
    FindVerseMarkerPos(MergedText, 1) <> FindVerseMarkerPos(MergedText, 10));

  { Legacy format without a space after verse number should still parse }
  MergedText := '\v 1Text one. \v 2Text two.';
  AssertTrue('Legacy marker format \\v 1Text is found for verse 1',
    FindVerseMarkerPos(MergedText, 1) > 0);
  AssertTrue('Legacy marker format \\v 2Text is found for verse 2',
    FindVerseMarkerPos(MergedText, 2) > 0);

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
        AssertEqInt('Split chunk count', 3, SplitResult.Count);
        AssertContains('Chunk 1 has verse 1', '\v 1', SplitResult[0].Content);
        AssertContains('Chunk 3 has verse 3', '\v 3', SplitResult[1].Content);
        AssertContains('Chunk 5 has verse 5', '\v 5', SplitResult[2].Content);
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

  { --- Split fallback for missing markers --- }
  WriteLn('--- Split fallback (missing markers) ---');
  Chapter := TChapter.Create('01');
  try
    Verses := TStringList.Create;
    try
      Verses.Add('01');
      Verses.Add('04');
      Verses.Add('07');
      MergedText := 'First section text. Second section text.';
      SplitResult := Chapter.SplitByChunkMap(MergedText, Verses);
      try
        AssertEqInt('Fallback split chunk count', 3, SplitResult.Count);
        AssertContains('Fallback chunk 01 gets inferred marker', '\v 01', SplitResult[0].Content);
        AssertTrue('Fallback keeps text in at least one chunk',
          (Trim(SplitResult[0].Content) <> '') or
          (Trim(SplitResult[1].Content) <> '') or
          (Trim(SplitResult[2].Content) <> ''));
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
  WriteLn('--- TStudioPackage ---');
  TempDir := GetTempDir(False) + DirectorySeparator + 'bttwriter2_tstudio_test';
  if DirectoryExists(TempDir) then
    DeleteFile(TempDir + DirectorySeparator + 'dummy'); { no-op to avoid rm -rf }
  ForceDirectories(TempDir);
  { Intentionally mismatch directory suffix vs manifest resource.id to verify
    export canonicalizes from the inner manifest. }
  ProjectPath := IncludeTrailingPathDelimiter(TempDir) + 'zz-demo_tit_text_reg';
  ForceDirectories(ProjectPath);
  ForceDirectories(IncludeTrailingPathDelimiter(ProjectPath) + '01');

  with TStringList.Create do
  try
    Text := '{' + LineEnding +
      '  "target_language":{"id":"zz-demo","name":"Demo","direction":"ltr"},' + LineEnding +
      '  "project":{"id":"tit","name":"Titus"},' + LineEnding +
      '  "type":{"id":"text","name":"Text"},' + LineEnding +
      '  "resource":{"id":"ulb","name":"Unlocked Literal Bible"},' + LineEnding +
      '  "source_translations":[{"language_id":"en","resource_id":"ulb"}]' + LineEnding +
      '}';
    SaveToFile(IncludeTrailingPathDelimiter(ProjectPath) + 'manifest.json');
  finally
    Free;
  end;
  with TStringList.Create do
  try
    Text := '\v 1 Demo verse.';
    SaveToFile(IncludeTrailingPathDelimiter(ProjectPath) + '01' + DirectorySeparator + '01.txt');
  finally
    Free;
  end;

  TempFile := IncludeTrailingPathDelimiter(TempDir) + 'zz-demo_tit_text_ulb.tstudio';
  MergedText := '';
  AssertTrue('Create .tstudio package',
    CreateTStudioPackage(ProjectPath, TempFile, MergedText));
  if MergedText <> '' then
    WriteLn('  Create message: ', MergedText);
  AssertFileExists('Created package', TempFile);

  MergedText := '';
  AssertTrue('Read .tstudio package info',
    ReadTStudioPackageInfo(TempFile, PkgInfo, MergedText));
  AssertTrue('Package version is 2', PkgInfo.PackageVersion = 2);
  AssertTrue('Project path set in package',
    PkgInfo.ProjectPath = 'zz-demo_tit_text_ulb');

  Extracted := '';
  MergedText := '';
  AssertTrue('Extract .tstudio package',
    ExtractTStudioPackage(TempFile, IncludeTrailingPathDelimiter(TempDir) + 'extract', Extracted, MergedText));
  AssertTrue('Extracted project directory exists', DirectoryExists(Extracted));
  AssertTrue('Extracted project manifest exists',
    FileExists(IncludeTrailingPathDelimiter(Extracted) + 'manifest.json'));

  ExtractedManifestText := '';
  with TStringList.Create do
  try
    LoadFromFile(IncludeTrailingPathDelimiter(Extracted) + 'manifest.json');
    ExtractedManifestText := Text;
  finally
    Free;
  end;
  ExtractedManifestData := GetJSON(ExtractedManifestText);
  try
    AssertTrue('Exported project manifest package_version is v1-compatible',
      (ExtractedManifestData is TJSONObject) and
      (TJSONObject(ExtractedManifestData).Get('package_version', 0) = 7));
  finally
    ExtractedManifestData.Free;
  end;

  WriteLn;
  if FailCount = 0 then
    WriteLn('=== All tests passed ===')
  else
  begin
    WriteLn('=== Tests failed: ', FailCount, ' ===');
    Halt(1);
  end;
end.
