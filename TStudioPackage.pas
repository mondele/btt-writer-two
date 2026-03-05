unit TStudioPackage;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes;

type
  TTStudioPackageInfo = record
    PackagePath: string;
    PackageVersion: Integer;
    GeneratorName: string;
    GeneratorBuild: string;
    TimestampMs: Int64;
    ProjectPath: string;
    ProjectID: string;
    Direction: string;
    CommitStdout: string;
    CommitStderr: string;
    CommitError: string; { empty means JSON null / no error }
  end;

function ReadTStudioPackageInfo(const PackagePath: string;
  out Info: TTStudioPackageInfo; out ErrorMsg: string): Boolean;
function CreateTStudioPackage(const ProjectDir, PackagePath: string;
  out ErrorMsg: string): Boolean;
function ExtractTStudioPackage(const PackagePath, DestRoot: string;
  out ExtractedProjectDir: string; out ErrorMsg: string): Boolean;

implementation

uses
  Process, fpjson, jsonparser, DateUtils;

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

function ReadJSONFile(const APath: string): TJSONObject;
var
  SL: TStringList;
  Data: TJSONData;
begin
  Result := nil;
  if not FileExists(APath) then
    Exit;
  SL := TStringList.Create;
  try
    SL.LoadFromFile(APath);
    Data := GetJSON(SL.Text);
    if Data is TJSONObject then
      Result := TJSONObject(Data)
    else
      Data.Free;
  finally
    SL.Free;
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

function ReadTStudioManifestJSON(const PackagePath: string;
  out ManifestObj: TJSONObject; out ErrorMsg: string): Boolean;
var
  OutText, ErrText: string;
  ExitCode: Integer;
  Data: TJSONData;
begin
  Result := False;
  ManifestObj := nil;
  ErrorMsg := '';

  if not FileExists(PackagePath) then
  begin
    ErrorMsg := 'Package not found: ' + PackagePath;
    Exit(False);
  end;

  if not RunCommandCapture('unzip', ['-p', PackagePath, 'manifest.json'], '',
    OutText, ErrText, ExitCode) then
  begin
    ErrorMsg := 'Failed to read package manifest.';
    Exit(False);
  end;
  if ExitCode <> 0 then
  begin
    ErrorMsg := 'Could not read manifest.json from package: ' + Trim(ErrText);
    Exit(False);
  end;

  try
    Data := GetJSON(OutText);
  except
    on E: Exception do
    begin
      ErrorMsg := 'Invalid package manifest JSON: ' + E.Message;
      Exit(False);
    end;
  end;
  if not (Data is TJSONObject) then
  begin
    Data.Free;
    ErrorMsg := 'Invalid package manifest structure.';
    Exit(False);
  end;

  ManifestObj := TJSONObject(Data);
  Result := True;
end;

function ReadTStudioPackageInfo(const PackagePath: string;
  out Info: TTStudioPackageInfo; out ErrorMsg: string): Boolean;
var
  ManifestObj, GenObj, EntryObj, CommitObj: TJSONObject;
  Arr: TJSONArray;
  Node: TJSONData;
begin
  Result := False;
  FillChar(Info, SizeOf(Info), 0);
  Info.PackagePath := PackagePath;
  ErrorMsg := '';

  if not ReadTStudioManifestJSON(PackagePath, ManifestObj, ErrorMsg) then
    Exit(False);
  try
    Info.PackageVersion := ManifestObj.Get('package_version', 0);
    Info.TimestampMs := ManifestObj.Get('timestamp', Int64(0));

    if ManifestObj.Find('generator') is TJSONObject then
    begin
      GenObj := TJSONObject(ManifestObj.Find('generator'));
      Info.GeneratorName := GenObj.Get('name', '');
      Info.GeneratorBuild := GenObj.Get('build', '');
    end;

    Node := ManifestObj.Find('target_translations');
    if not (Node is TJSONArray) then
    begin
      ErrorMsg := 'manifest target_translations missing.';
      Exit(False);
    end;
    Arr := TJSONArray(Node);
    if Arr.Count < 1 then
    begin
      ErrorMsg := 'manifest target_translations empty.';
      Exit(False);
    end;
    if not (Arr.Items[0] is TJSONObject) then
    begin
      ErrorMsg := 'manifest target_translations[0] invalid.';
      Exit(False);
    end;
    EntryObj := TJSONObject(Arr.Items[0]);
    Info.ProjectPath := EntryObj.Get('path', '');
    Info.ProjectID := EntryObj.Get('id', '');
    Info.Direction := EntryObj.Get('direction', 'ltr');

    if EntryObj.Find('commit_hash') is TJSONObject then
    begin
      CommitObj := TJSONObject(EntryObj.Find('commit_hash'));
      Info.CommitStdout := CommitObj.Get('stdout', '');
      Info.CommitStderr := CommitObj.Get('stderr', '');
      Node := CommitObj.Find('error');
      if (Node = nil) or (Node.JSONType = jtNull) then
        Info.CommitError := ''
      else
        Info.CommitError := Node.AsString;
    end;

    Result := (Info.ProjectPath <> '');
    if not Result then
      ErrorMsg := 'manifest missing target project path.';
  finally
    ManifestObj.Free;
  end;
end;

function CreateTStudioPackage(const ProjectDir, PackagePath: string;
  out ErrorMsg: string): Boolean;
var
  ProjectName, CanonicalName, TempRoot, StageDir, ManifestPath, OutText, ErrText,
  Direction, StagedInnerManifestJSON, StagedManifestPath: string;
  ExitCode: Integer;
  InnerManifest, OuterManifest, GenObj, EntryObj, CommitObj: TJSONObject;
  Arr: TJSONArray;
  DirNode, LangNode, ProjNode, TypeNode, ResNode: TJSONData;
  SL: TStringList;
  CommitErr: string;
begin
  Result := False;
  ErrorMsg := '';

  if not DirectoryExists(ProjectDir) then
  begin
    ErrorMsg := 'Project directory does not exist: ' + ProjectDir;
    Exit(False);
  end;
  ProjectName := ExtractFileName(ExcludeTrailingPathDelimiter(ProjectDir));
  if ProjectName = '' then
  begin
    ErrorMsg := 'Invalid project directory.';
    Exit(False);
  end;
  ManifestPath := IncludeTrailingPathDelimiter(ProjectDir) + 'manifest.json';
  if not FileExists(ManifestPath) then
  begin
    ErrorMsg := 'Project manifest missing: ' + ManifestPath;
    Exit(False);
  end;

  if not EnsureProjectCommitted(ProjectDir, ErrorMsg) then
    Exit(False);

  InnerManifest := ReadJSONFile(ManifestPath);
  if InnerManifest = nil then
  begin
    ErrorMsg := 'Could not parse project manifest.';
    Exit(False);
  end;
  try
    CanonicalName := ProjectName;
    Direction := 'ltr';
    DirNode := InnerManifest.FindPath('target_language.direction');
    LangNode := InnerManifest.FindPath('target_language.id');
    ProjNode := InnerManifest.FindPath('project.id');
    TypeNode := InnerManifest.FindPath('type.id');
    ResNode := InnerManifest.FindPath('resource.id');
    if DirNode <> nil then
      Direction := DirNode.AsString;
    if (LangNode <> nil) and (ProjNode <> nil) and (TypeNode <> nil) and (ResNode <> nil) and
       (Trim(LangNode.AsString) <> '') and (Trim(ProjNode.AsString) <> '') and
       (Trim(TypeNode.AsString) <> '') and (Trim(ResNode.AsString) <> '') then
      CanonicalName :=
        Trim(LangNode.AsString) + '_' +
        Trim(ProjNode.AsString) + '_' +
        Trim(TypeNode.AsString) + '_' +
        Trim(ResNode.AsString);

    { v1 desktop migrator requires package_version=7 for project manifests.
      Keep local project manifest untouched; normalize only in staged export. }
    if InnerManifest.IndexOfName('package_version') >= 0 then
      InnerManifest.Delete('package_version');
    InnerManifest.Add('package_version', 7);
    StagedInnerManifestJSON := InnerManifest.FormatJSON;
  finally
    InnerManifest.Free;
  end;

  CommitErr := '';
  if not RunCommandCapture('git', ['-C', ProjectDir, 'rev-parse', 'HEAD'], '',
    OutText, ErrText, ExitCode) then
  begin
    OutText := '';
    ErrText := '';
    CommitErr := 'git unavailable';
  end
  else if ExitCode <> 0 then
    CommitErr := Trim(ErrText);

  OuterManifest := TJSONObject.Create;
  try
    GenObj := TJSONObject.Create;
    GenObj.Add('name', 'btt-writer-two');
    GenObj.Add('build', 'codex');
    OuterManifest.Add('generator', GenObj);
    OuterManifest.Add('package_version', 2);
    OuterManifest.Add('timestamp', DateTimeToUnix(Now, False) * Int64(1000));

    Arr := TJSONArray.Create;
    EntryObj := TJSONObject.Create;
    EntryObj.Add('path', CanonicalName);
    EntryObj.Add('id', CanonicalName);
    CommitObj := TJSONObject.Create;
    CommitObj.Add('stdout', OutText);
    CommitObj.Add('stderr', ErrText);
    if CommitErr = '' then
      CommitObj.Add('error', TJSONNull.Create)
    else
      CommitObj.Add('error', CommitErr);
    EntryObj.Add('commit_hash', CommitObj);
    EntryObj.Add('direction', Direction);
    Arr.Add(EntryObj);
    OuterManifest.Add('target_translations', Arr);

    TempRoot := IncludeTrailingPathDelimiter(GetTempDir(False)) +
      'bttwriter2_tstudio_' + IntToHex(Random(MaxInt), 8);
    if not ForceDirectories(TempRoot) then
    begin
      ErrorMsg := 'Could not create temp directory.';
      Exit(False);
    end;
    StageDir := TempRoot;

    SL := TStringList.Create;
    try
      SL.Text := OuterManifest.FormatJSON;
      SL.SaveToFile(IncludeTrailingPathDelimiter(StageDir) + 'manifest.json');
    finally
      SL.Free;
    end;

    if not RunCommandCapture('bash',
      ['-lc', 'cp -a ' + ShellQuote(ExcludeTrailingPathDelimiter(ProjectDir)) + ' ' +
       ShellQuote(StageDir + DirectorySeparator + CanonicalName)],
      '', OutText, ErrText, ExitCode) then
    begin
      ErrorMsg := 'Failed staging project files.';
      Exit(False);
    end;
    if ExitCode <> 0 then
    begin
      ErrorMsg := 'Failed staging project files: ' + Trim(ErrText);
      Exit(False);
    end;

    StagedManifestPath := IncludeTrailingPathDelimiter(StageDir) + CanonicalName +
      DirectorySeparator + 'manifest.json';
    SL := TStringList.Create;
    try
      SL.Text := StagedInnerManifestJSON;
      SL.SaveToFile(StagedManifestPath);
    finally
      SL.Free;
    end;

    if not RunCommandCapture('bash',
      ['-lc', 'cd ' + ShellQuote(StageDir) + ' && zip -rq ' +
       ShellQuote(PackagePath) + ' manifest.json ' + ShellQuote(CanonicalName)],
      '', OutText, ErrText, ExitCode) then
    begin
      ErrorMsg := 'Failed creating package zip.';
      Exit(False);
    end;
    if ExitCode <> 0 then
    begin
      ErrorMsg := 'Failed creating package zip: ' + Trim(ErrText);
      Exit(False);
    end;

    Result := FileExists(PackagePath);
    if not Result then
      ErrorMsg := 'Package was not created.';
  finally
    OuterManifest.Free;
    if TempRoot <> '' then
      RunCommandCapture('bash', ['-lc', 'rm -rf ' + ShellQuote(TempRoot)],
        '', OutText, ErrText, ExitCode);
  end;
end;

function ExtractTStudioPackage(const PackagePath, DestRoot: string;
  out ExtractedProjectDir: string; out ErrorMsg: string): Boolean;
var
  Info: TTStudioPackageInfo;
  OutText, ErrText: string;
  ExitCode: Integer;
begin
  Result := False;
  ExtractedProjectDir := '';
  ErrorMsg := '';

  if not ReadTStudioPackageInfo(PackagePath, Info, ErrorMsg) then
    Exit(False);

  if not ForceDirectories(DestRoot) then
  begin
    ErrorMsg := 'Could not create destination directory.';
    Exit(False);
  end;

  if not RunCommandCapture('unzip', ['-oq', PackagePath, '-d', DestRoot], '',
    OutText, ErrText, ExitCode) then
  begin
    ErrorMsg := 'Failed extracting package.';
    Exit(False);
  end;
  if ExitCode <> 0 then
  begin
    ErrorMsg := 'Failed extracting package: ' + Trim(ErrText);
    Exit(False);
  end;

  ExtractedProjectDir := IncludeTrailingPathDelimiter(DestRoot) + Info.ProjectPath;
  if not DirectoryExists(ExtractedProjectDir) then
  begin
    ErrorMsg := 'Extracted project directory missing.';
    Exit(False);
  end;

  Result := True;
end;

end.
