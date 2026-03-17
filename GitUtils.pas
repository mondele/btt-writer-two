unit GitUtils;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes;

type
  TConflictChunk = record
    FilePath: string;      { relative path within project, e.g. '03/01.txt' }
    OursText: string;      { local version }
    TheirsText: string;    { incoming version }
  end;
  TConflictChunkArray = array of TConflictChunk;

function RunCommandCapture(const Exe: string; const Args: array of string;
  const WorkDir: string; out OutputText, ErrorText: string;
  out ExitCode: Integer): Boolean;
function EnsureProjectCommitted(const ProjectDir: string; out ErrorMsg: string): Boolean;
function ShellQuote(const S: string): string;

{ Merge an incoming project directory into an existing local project.
  Returns True if merge completed (possibly with conflicts).
  HasConflicts is set True if unresolved conflicts remain. }
function MergeImportedProject(const LocalDir, ImportedDir: string;
  out HasConflicts: Boolean; out ErrorMsg: string): Boolean;

{ List files with unresolved merge conflicts. }
function ListConflictFiles(const ProjectDir: string): TStringArray;

{ Parse git conflict markers from a file into ours/theirs sections. }
function ParseConflictMarkers(const FileContent: string;
  out OursText, TheirsText: string): Boolean;

{ Resolve a single file by writing chosen content and staging it. }
function ResolveConflictFile(const ProjectDir, RelPath, ResolvedText: string;
  out ErrorMsg: string): Boolean;

{ Finalize merge after all conflicts are resolved. }
function FinalizeMerge(const ProjectDir: string; out ErrorMsg: string): Boolean;

{ Check if a project has unresolved merge conflicts. }
function ProjectHasConflicts(const ProjectDir: string): Boolean;

{ Move a directory, handling cross-filesystem moves (RenameFile fallback to
  cp -a + rm). Returns True on success. }
function MoveDirectorySafe(const SrcDir, DestDir: string): Boolean;

implementation

uses
  Process, fpjson, jsonparser;

function ShellQuote(const S: string): string;
begin
  Result := '''' + StringReplace(S, '''', '''"''"''', [rfReplaceAll]) + '''';
end;

function RunCommandCapture(const Exe: string; const Args: array of string;
  const WorkDir: string; out OutputText, ErrorText: string;
  out ExitCode: Integer): Boolean;
var
  P: TProcess;
  OutS, ErrS: TStringStream;
  I: Integer;
  Buf: array[0..4095] of Byte;
  N: LongInt;
begin
  Result := False;
  OutputText := '';
  ErrorText := '';
  ExitCode := -1;

  P := TProcess.Create(nil);
  OutS := TStringStream.Create('');
  ErrS := TStringStream.Create('');
  try
    P.Executable := Exe;
    if WorkDir <> '' then
      P.CurrentDirectory := WorkDir;
    P.Options := [poUsePipes];
    for I := 0 to High(Args) do
      P.Parameters.Add(Args[I]);
    try
      P.Execute;
    except
      on E: Exception do
      begin
        ErrorText := E.Message;
        Exit(False);
      end;
    end;

    while P.Running do
    begin
      while P.Output.NumBytesAvailable > 0 do
      begin
        N := P.Output.Read(Buf, SizeOf(Buf));
        if N > 0 then
          OutS.WriteBuffer(Buf, N);
      end;
      while P.Stderr.NumBytesAvailable > 0 do
      begin
        N := P.Stderr.Read(Buf, SizeOf(Buf));
        if N > 0 then
          ErrS.WriteBuffer(Buf, N);
      end;
      Sleep(5);
    end;
    while P.Output.NumBytesAvailable > 0 do
    begin
      N := P.Output.Read(Buf, SizeOf(Buf));
      if N > 0 then
        OutS.WriteBuffer(Buf, N);
    end;
    while P.Stderr.NumBytesAvailable > 0 do
    begin
      N := P.Stderr.Read(Buf, SizeOf(Buf));
      if N > 0 then
        ErrS.WriteBuffer(Buf, N);
    end;

    OutputText := OutS.DataString;
    ErrorText := ErrS.DataString;
    ExitCode := P.ExitStatus;
    Result := True;
  finally
    ErrS.Free;
    OutS.Free;
    P.Free;
  end;
end;

function EnsureProjectCommitted(const ProjectDir: string; out ErrorMsg: string): Boolean;
var
  OutText, ErrText: string;
  ExitCode: Integer;
begin
  Result := False;
  ErrorMsg := '';

  { If this is not a git repo, skip commit enforcement. }
  if not RunCommandCapture('git', ['-C', ProjectDir, 'rev-parse', '--is-inside-work-tree'],
    '', OutText, ErrText, ExitCode) then
    Exit(True);
  if (ExitCode <> 0) or (Pos('true', LowerCase(OutText)) = 0) then
    Exit(True);

  if not RunCommandCapture('git', ['-C', ProjectDir, 'status', '--porcelain'],
    '', OutText, ErrText, ExitCode) then
  begin
    ErrorMsg := 'Could not read git status.';
    Exit(False);
  end;
  if ExitCode <> 0 then
  begin
    ErrorMsg := Trim(ErrText);
    Exit(False);
  end;
  if Trim(OutText) = '' then
    Exit(True);

  if not RunCommandCapture('git', ['-C', ProjectDir, 'add', '-A'],
    '', OutText, ErrText, ExitCode) then
  begin
    ErrorMsg := 'Could not stage project changes.';
    Exit(False);
  end;
  if ExitCode <> 0 then
  begin
    ErrorMsg := Trim(ErrText);
    Exit(False);
  end;

  if not RunCommandCapture('git',
    ['-C', ProjectDir, 'commit', '-m', 'Export snapshot'],
    '', OutText, ErrText, ExitCode) then
  begin
    ErrorMsg := 'Could not create export commit.';
    Exit(False);
  end;
  if ExitCode <> 0 then
  begin
    if Pos('nothing to commit', LowerCase(ErrText + OutText)) > 0 then
      Exit(True);
    ErrorMsg := Trim(ErrText);
    if ErrorMsg = '' then
      ErrorMsg := Trim(OutText);
    Exit(False);
  end;

  Result := True;
end;

{ Union a JSON string array: add items from Src to Dest, skipping duplicates. }
procedure UnionJSONStringArrays(Dest, Src: TJSONArray);
var
  I, J: Integer;
  Val: string;
  Found: Boolean;
begin
  for I := 0 to Src.Count - 1 do
  begin
    Val := Src.Strings[I];
    Found := False;
    for J := 0 to Dest.Count - 1 do
      if Dest.Strings[J] = Val then
      begin
        Found := True;
        Break;
      end;
    if not Found then
      Dest.Add(Val);
  end;
end;

{ Remove an item from a JSON string array by value. }
procedure RemoveJSONStringItem(Arr: TJSONArray; const Val: string);
var
  I: Integer;
begin
  for I := Arr.Count - 1 downto 0 do
    if Arr.Strings[I] = Val then
    begin
      Arr.Delete(I);
      Break;
    end;
end;

{ Pre-merge two manifest.json objects: union translators and finished_chunks.
  Result is based on LocalManifest with arrays merged from RemoteManifest. }
function PreMergeManifests(LocalManifest, RemoteManifest: TJSONObject): TJSONObject;
var
  MergedArr: TJSONArray;
  LocalArr, RemoteArr: TJSONArray;
  Idx, I: Integer;
begin
  { Clone local manifest as the base }
  Result := TJSONObject(LocalManifest.Clone);

  { Merge translators }
  if (Result.Find('translators') is TJSONArray) and
     (RemoteManifest.Find('translators') is TJSONArray) then
  begin
    UnionJSONStringArrays(
      TJSONArray(Result.Find('translators')),
      TJSONArray(RemoteManifest.Find('translators')));
  end
  else if (RemoteManifest.Find('translators') is TJSONArray) then
  begin
    MergedArr := TJSONArray(TJSONArray(RemoteManifest.Find('translators')).Clone);
    Idx := Result.IndexOfName('translators');
    if Idx >= 0 then
      Result.Delete(Idx);
    Result.Add('translators', MergedArr);
  end;

  { Merge finished_chunks }
  if (Result.Find('finished_chunks') is TJSONArray) and
     (RemoteManifest.Find('finished_chunks') is TJSONArray) then
  begin
    UnionJSONStringArrays(
      TJSONArray(Result.Find('finished_chunks')),
      TJSONArray(RemoteManifest.Find('finished_chunks')));
  end
  else if (RemoteManifest.Find('finished_chunks') is TJSONArray) then
  begin
    MergedArr := TJSONArray(TJSONArray(RemoteManifest.Find('finished_chunks')).Clone);
    Idx := Result.IndexOfName('finished_chunks');
    if Idx >= 0 then
      Result.Delete(Idx);
    Result.Add('finished_chunks', MergedArr);
  end;
end;

function MergeImportedProject(const LocalDir, ImportedDir: string;
  out HasConflicts: Boolean; out ErrorMsg: string): Boolean;
var
  OutText, ErrText: string;
  ExitCode: Integer;
  LocalManifestPath, RemoteManifestPath: string;
  SL: TStringList;
  LocalData, RemoteData: TJSONData;
  MergedManifest: TJSONObject;
  ConflictFiles: TStringArray;
  ChunkID, RelPath: string;
  I, SlashPos: Integer;
begin
  Result := False;
  HasConflicts := False;
  ErrorMsg := '';

  { Ensure local project has all changes committed }
  if not EnsureProjectCommitted(LocalDir, ErrorMsg) then
    Exit;

  { ---- Step 1: Pre-read both manifests BEFORE git merge (v1 strategy) ---- }
  LocalManifestPath := IncludeTrailingPathDelimiter(LocalDir) + 'manifest.json';
  RemoteManifestPath := IncludeTrailingPathDelimiter(ImportedDir) + 'manifest.json';
  LocalData := nil;
  RemoteData := nil;
  MergedManifest := nil;

  SL := TStringList.Create;
  try
    if FileExists(LocalManifestPath) then
    begin
      SL.LoadFromFile(LocalManifestPath);
      try
        LocalData := GetJSON(SL.Text);
      except
        LocalData := nil;
      end;
    end;
    if FileExists(RemoteManifestPath) then
    begin
      SL.LoadFromFile(RemoteManifestPath);
      try
        RemoteData := GetJSON(SL.Text);
      except
        RemoteData := nil;
      end;
    end;

    { Pre-merge manifests: union translators and finished_chunks }
    if (LocalData is TJSONObject) and (RemoteData is TJSONObject) then
      MergedManifest := PreMergeManifests(
        TJSONObject(LocalData), TJSONObject(RemoteData))
    else if LocalData is TJSONObject then
      MergedManifest := TJSONObject(LocalData.Clone)
    else if RemoteData is TJSONObject then
      MergedManifest := TJSONObject(RemoteData.Clone);
  finally
    SL.Free;
    LocalData.Free;
    RemoteData.Free;
  end;

  { ---- Step 2: Perform git merge ---- }

  { Remove any previous import remote }
  RunCommandCapture('git', ['-C', LocalDir, 'remote', 'remove', 'import'],
    '', OutText, ErrText, ExitCode);

  { Add the imported directory as a remote }
  if not RunCommandCapture('git', ['-C', LocalDir, 'remote', 'add', 'import',
    ImportedDir], '', OutText, ErrText, ExitCode) then
  begin
    ErrorMsg := 'Could not add import remote: ' + ErrText;
    MergedManifest.Free;
    Exit;
  end;
  if ExitCode <> 0 then
  begin
    ErrorMsg := 'Could not add import remote: ' + Trim(ErrText);
    MergedManifest.Free;
    Exit;
  end;

  { Fetch from imported }
  if not RunCommandCapture('git', ['-C', LocalDir, 'fetch', 'import'],
    '', OutText, ErrText, ExitCode) then
  begin
    ErrorMsg := 'Fetch failed: ' + ErrText;
    RunCommandCapture('git', ['-C', LocalDir, 'remote', 'remove', 'import'],
      '', OutText, ErrText, ExitCode);
    MergedManifest.Free;
    Exit;
  end;
  if ExitCode <> 0 then
  begin
    ErrorMsg := 'Fetch failed: ' + Trim(ErrText);
    RunCommandCapture('git', ['-C', LocalDir, 'remote', 'remove', 'import'],
      '', OutText, ErrText, ExitCode);
    MergedManifest.Free;
    Exit;
  end;

  { Attempt merge — allow unrelated histories since projects may have
    been created independently }
  RunCommandCapture('git', ['-C', LocalDir, 'merge',
    '--allow-unrelated-histories', '--no-edit', 'import/master'],
    '', OutText, ErrText, ExitCode);

  { Clean up remote regardless of merge outcome }
  RunCommandCapture('git', ['-C', LocalDir, 'remote', 'remove', 'import'],
    '', OutText, ErrText, ExitCode);

  { ---- Step 3: Write pre-merged manifest, removing conflicted chunks
    from finished_chunks (v1 behavior) ---- }
  ConflictFiles := ListConflictFiles(LocalDir);

  if MergedManifest <> nil then
  begin
    try
      { For each conflicted chunk file, remove it from finished_chunks }
      if MergedManifest.Find('finished_chunks') is TJSONArray then
      begin
        for I := 0 to Length(ConflictFiles) - 1 do
        begin
          RelPath := ConflictFiles[I];
          if RelPath = 'manifest.json' then
            Continue;
          { Convert path like "02/01.txt" to chunk ID "02-01" }
          SlashPos := Pos('/', RelPath);
          if SlashPos > 0 then
          begin
            ChunkID := Copy(RelPath, 1, SlashPos - 1) + '-' +
              ChangeFileExt(Copy(RelPath, SlashPos + 1, MaxInt), '');
            RemoveJSONStringItem(
              TJSONArray(MergedManifest.Find('finished_chunks')), ChunkID);
          end;
        end;
      end;

      { Write merged manifest — overwrites any conflict markers git left }
      SL := TStringList.Create;
      try
        SL.Text := MergedManifest.FormatJSON;
        SL.SaveToFile(LocalManifestPath);
      finally
        SL.Free;
      end;

      { Stage the clean manifest }
      RunCommandCapture('git', ['-C', LocalDir, 'add', 'manifest.json'],
        '', OutText, ErrText, ExitCode);
    finally
      MergedManifest.Free;
    end;
  end;

  { ---- Step 4: Check for remaining conflicts (chunk .txt files only) ---- }
  ConflictFiles := ListConflictFiles(LocalDir);
  if Length(ConflictFiles) > 0 then
  begin
    HasConflicts := True;
    Result := True;
    Exit;
  end;

  { If no conflicts remain, finalize the merge }
  FinalizeMerge(LocalDir, ErrorMsg);

  Result := True;
end;

function ListConflictFiles(const ProjectDir: string): TStringArray;
var
  OutText, ErrText: string;
  ExitCode: Integer;
  Lines: TStringList;
  I, Count: Integer;
begin
  SetLength(Result, 0);
  if not RunCommandCapture('git', ['-C', ProjectDir, 'diff',
    '--name-only', '--diff-filter=U'], '', OutText, ErrText, ExitCode) then
    Exit;
  if ExitCode <> 0 then
    Exit;

  Lines := TStringList.Create;
  try
    Lines.Text := Trim(OutText);
    Count := 0;
    SetLength(Result, Lines.Count);
    for I := 0 to Lines.Count - 1 do
    begin
      if Trim(Lines[I]) <> '' then
      begin
        Result[Count] := Trim(Lines[I]);
        Inc(Count);
      end;
    end;
    SetLength(Result, Count);
  finally
    Lines.Free;
  end;
end;

function ParseConflictMarkers(const FileContent: string;
  out OursText, TheirsText: string): Boolean;
var
  Lines: TStringList;
  I: Integer;
  InOurs, InTheirs: Boolean;
  OursList, TheirsList: TStringList;
begin
  Result := False;
  OursText := '';
  TheirsText := '';
  InOurs := False;
  InTheirs := False;

  Lines := TStringList.Create;
  OursList := TStringList.Create;
  TheirsList := TStringList.Create;
  try
    Lines.Text := FileContent;
    for I := 0 to Lines.Count - 1 do
    begin
      if Pos('<<<<<<<', Lines[I]) = 1 then
      begin
        InOurs := True;
        InTheirs := False;
        Result := True;
      end
      else if Pos('=======', Lines[I]) = 1 then
      begin
        InOurs := False;
        InTheirs := True;
      end
      else if Pos('>>>>>>>', Lines[I]) = 1 then
      begin
        InOurs := False;
        InTheirs := False;
      end
      else if InOurs then
        OursList.Add(Lines[I])
      else if InTheirs then
        TheirsList.Add(Lines[I])
      else
      begin
        { Content outside conflict markers — common to both }
        OursList.Add(Lines[I]);
        TheirsList.Add(Lines[I]);
      end;
    end;
    OursText := Trim(OursList.Text);
    TheirsText := Trim(TheirsList.Text);
  finally
    TheirsList.Free;
    OursList.Free;
    Lines.Free;
  end;
end;

function ResolveConflictFile(const ProjectDir, RelPath, ResolvedText: string;
  out ErrorMsg: string): Boolean;
var
  FullPath, OutText, ErrText: string;
  SL: TStringList;
  ExitCode: Integer;
begin
  Result := False;
  ErrorMsg := '';
  FullPath := IncludeTrailingPathDelimiter(ProjectDir) + RelPath;

  SL := TStringList.Create;
  try
    SL.Text := ResolvedText;
    try
      SL.SaveToFile(FullPath);
    except
      on E: Exception do
      begin
        ErrorMsg := 'Could not write resolved file: ' + E.Message;
        Exit;
      end;
    end;
  finally
    SL.Free;
  end;

  if not RunCommandCapture('git', ['-C', ProjectDir, 'add', RelPath],
    '', OutText, ErrText, ExitCode) then
  begin
    ErrorMsg := 'Could not stage resolved file: ' + ErrText;
    Exit;
  end;
  if ExitCode <> 0 then
  begin
    ErrorMsg := 'Could not stage resolved file: ' + Trim(ErrText);
    Exit;
  end;

  Result := True;
end;

function FinalizeMerge(const ProjectDir: string; out ErrorMsg: string): Boolean;
var
  OutText, ErrText: string;
  ExitCode: Integer;
begin
  Result := False;
  ErrorMsg := '';

  { Check no conflicts remain }
  if Length(ListConflictFiles(ProjectDir)) > 0 then
  begin
    ErrorMsg := 'There are still unresolved conflicts.';
    Exit;
  end;

  if not RunCommandCapture('git', ['-C', ProjectDir, 'commit', '--no-edit'],
    '', OutText, ErrText, ExitCode) then
  begin
    ErrorMsg := 'Could not finalize merge commit: ' + ErrText;
    Exit;
  end;
  if ExitCode <> 0 then
  begin
    if Pos('nothing to commit', LowerCase(OutText + ErrText)) > 0 then
      Exit(True);
    ErrorMsg := 'Could not finalize merge commit: ' + Trim(ErrText);
    Exit;
  end;

  Result := True;
end;

function ProjectHasConflicts(const ProjectDir: string): Boolean;
begin
  Result := Length(ListConflictFiles(ProjectDir)) > 0;
end;

function MoveDirectorySafe(const SrcDir, DestDir: string): Boolean;
var
  OutText, ErrText: string;
  ExitCode: Integer;
begin
  { Try fast same-filesystem rename first }
  if RenameFile(SrcDir, DestDir) then
    Exit(True);

  { Cross-filesystem: copy then remove source }
  if not RunCommandCapture('cp', ['-a',
    ExcludeTrailingPathDelimiter(SrcDir),
    ExcludeTrailingPathDelimiter(DestDir)],
    '', OutText, ErrText, ExitCode) then
    Exit(False);
  if ExitCode <> 0 then
    Exit(False);

  { Remove source }
  RunCommandCapture('rm', ['-rf', ExcludeTrailingPathDelimiter(SrcDir)],
    '', OutText, ErrText, ExitCode);
  Result := True;
end;

end.
