{$mode objfpc}{$H+}
unit ProjectImporter;

{ LCL-free backend for .tstudio and server-repo import.
  All file I/O and git operations; no UI dependencies.

  Callers:
    - The CGE GameViewImport view uses these directly.
    - MainForm.pas can delegate to these instead of its inline code. }

interface

type
  TImportOutcome = (
    ioSuccess,
    ioDuplicateExists,     { target dir already present; caller should ask user }
    ioMergedWithConflicts, { merge succeeded but conflict markers remain }
    ioError
  );

  TDuplicateAction = (
    daNone,      { internal: no conflict yet }
    daOverwrite,
    daMerge
  );

{ Import a .tstudio package file.
  If the target project already exists, DupAction selects how to proceed.
  Pass daOverwrite or daMerge only when the caller has already confirmed with
  the user; otherwise pass daNone and check for ioDuplicateExists in return. }
function ImportTStudioFile(const FilePath: string;
  DupAction: TDuplicateAction;
  out ProjectName: string; out ErrorMsg: string): TImportOutcome;

{ Import a project already cloned into CloneDir (a temp dir).
  RepoName is the fallback if the manifest has no canonical dir info.
  Caller owns CloneDir and should clean it up regardless of result. }
function ImportClonedRepo(const CloneDir, RepoName: string;
  DupAction: TDuplicateAction;
  out ProjectName: string; out ErrorMsg: string): TImportOutcome;

{ Clone a remote HTTPS URL into a temp directory, read the canonical project
  name, then import via ImportClonedRepo.  Token is injected into the URL
  for authentication (pass '' for anonymous). }
function CloneAndImport(const CloneURL, Token: string;
  DupAction: TDuplicateAction;
  out ProjectName: string; out ErrorMsg: string): TImportOutcome;

implementation

uses
  SysUtils, DateUtils,
  TStudioPackage, GitUtils, DataPaths, ProjectScanner;

{ ── Helpers ── }

function TempTag: string;
begin
  Result := FormatDateTime('yyyymmddhhnnsszzz', Now);
end;

procedure Cleanup(const Dir: string);
var
  OutText, ErrText: string;
  ExitCode: Integer;
begin
  if Dir <> '' then
    RunCommandCapture('bash', ['-lc', 'rm -rf ' + ShellQuote(Dir)],
      '', OutText, ErrText, ExitCode);
end;

{ ── ExtractTStudioToCanonical ── }

function ExtractTStudioToCanonical(const PackagePath, DestRoot: string;
  out FinalDir: string; out ErrMsg: string): Boolean;
var
  TmpRoot, ExtractedDir, CanonName, CanonDir: string;
begin
  Result   := False;
  FinalDir := '';
  TmpRoot  := GetTempDir + 'bttw_ext_' + TempTag;
  ForceDirectories(TmpRoot);

  if not ExtractTStudioPackage(PackagePath, TmpRoot, ExtractedDir, ErrMsg) then
  begin
    Cleanup(TmpRoot);
    Exit;
  end;

  if not FileExists(IncludeTrailingPathDelimiter(ExtractedDir) + 'manifest.json') then
  begin
    ErrMsg := 'manifest.json not found in extracted project.';
    Cleanup(TmpRoot);
    Exit;
  end;

  CanonName := ReadCanonicalDirName(ExtractedDir);
  if CanonName = '' then
    CanonName := ExtractFileName(ExcludeTrailingPathDelimiter(ExtractedDir));

  CanonDir := IncludeTrailingPathDelimiter(DestRoot) + CanonName;
  FinalDir := CanonDir;

  if not DirectoryExists(DestRoot) then
    ForceDirectories(DestRoot);

  if DirectoryExists(CanonDir) then
    Cleanup(CanonDir);

  MoveDirectorySafe(ExtractedDir, CanonDir);
  Cleanup(TmpRoot);

  { Remove stale outer manifest.json }
  if FileExists(IncludeTrailingPathDelimiter(DestRoot) + 'manifest.json') then
    DeleteFile(IncludeTrailingPathDelimiter(DestRoot) + 'manifest.json');

  Result := True;
end;

{ ── Public functions ── }

function ImportTStudioFile(const FilePath: string;
  DupAction: TDuplicateAction;
  out ProjectName: string; out ErrorMsg: string): TImportOutcome;
var
  TempDir, ExtractedDir, CanonName, TargetDir: string;
  HasConflicts: Boolean;
  ErrMsg: string;
begin
  Result      := ioError;
  ProjectName := '';
  ErrorMsg    := '';

  { Peek at canonical name without committing to an extraction location }
  TempDir := GetTempDir + 'bttw_peek_' + TempTag;
  ForceDirectories(TempDir);
  if ExtractTStudioPackage(FilePath, TempDir, ExtractedDir, ErrMsg) then
    CanonName := ReadCanonicalDirName(ExtractedDir)
  else
    CanonName := '';
  Cleanup(TempDir);

  if CanonName = '' then
  begin
    { Fall back: read outer package info for project path }
    CanonName := ExtractFileName(ExcludeTrailingPathDelimiter(FilePath));
    { Strip .tstudio extension if present }
    if LowerCase(ExtractFileExt(CanonName)) = '.tstudio' then
      CanonName := ChangeFileExt(CanonName, '');
  end;

  ProjectName := CanonName;
  TargetDir   := IncludeTrailingPathDelimiter(GetTargetTranslationsPath) + CanonName;

  if DirectoryExists(TargetDir) then
  begin
    case DupAction of
      daNone:
      begin
        Result := ioDuplicateExists;
        Exit;
      end;
      daOverwrite:
      begin
        Cleanup(TargetDir);
        if not ExtractTStudioToCanonical(FilePath, GetTargetTranslationsPath,
          ExtractedDir, ErrMsg) then
        begin
          ErrorMsg := ErrMsg;
          Exit;
        end;
        EnsureProjectCommitted(ExtractedDir, ErrMsg);
        Result := ioSuccess;
        Exit;
      end;
      daMerge:
      begin
        TempDir := GetTempDir + 'bttw_import_' + TempTag;
        ForceDirectories(TempDir);
        if not ExtractTStudioToCanonical(FilePath, TempDir, ExtractedDir, ErrMsg) then
        begin
          ErrorMsg := ErrMsg;
          Cleanup(TempDir);
          Exit;
        end;
        EnsureProjectCommitted(ExtractedDir, ErrMsg);
        if not MergeImportedProject(TargetDir, ExtractedDir, HasConflicts, ErrMsg) then
        begin
          ErrorMsg := ErrMsg;
          Cleanup(TempDir);
          Exit;
        end;
        Cleanup(TempDir);
        if HasConflicts then
          Result := ioMergedWithConflicts
        else
          Result := ioSuccess;
        Exit;
      end;
    end;
  end;

  { No existing project }
  if not ExtractTStudioToCanonical(FilePath, GetTargetTranslationsPath,
    ExtractedDir, ErrMsg) then
  begin
    ErrorMsg := ErrMsg;
    Exit;
  end;
  EnsureProjectCommitted(ExtractedDir, ErrMsg);
  Result := ioSuccess;
end;

function ImportClonedRepo(const CloneDir, RepoName: string;
  DupAction: TDuplicateAction;
  out ProjectName: string; out ErrorMsg: string): TImportOutcome;
var
  CanonName, TargetDir: string;
  HasConflicts: Boolean;
  ErrMsg: string;
begin
  Result      := ioError;
  ProjectName := '';
  ErrorMsg    := '';

  if not FileExists(IncludeTrailingPathDelimiter(CloneDir) + 'manifest.json') then
  begin
    ErrorMsg := 'Repository does not contain a valid BTT-Writer project (manifest.json missing).';
    Exit;
  end;

  CanonName := ReadCanonicalDirName(CloneDir);
  if CanonName = '' then
    CanonName := RepoName;
  ProjectName := CanonName;
  TargetDir   := IncludeTrailingPathDelimiter(GetTargetTranslationsPath) + CanonName;

  if DirectoryExists(TargetDir) then
  begin
    case DupAction of
      daNone:
      begin
        Result := ioDuplicateExists;
        Exit;
      end;
      daOverwrite:
      begin
        Cleanup(TargetDir);
        ForceDirectories(GetTargetTranslationsPath);
        if not MoveDirectorySafe(CloneDir, TargetDir) then
        begin
          ErrorMsg := 'Could not move project to ' + TargetDir;
          Exit;
        end;
        Result := ioSuccess;
        Exit;
      end;
      daMerge:
      begin
        if not MergeImportedProject(TargetDir, CloneDir, HasConflicts, ErrMsg) then
        begin
          ErrorMsg := ErrMsg;
          Exit;
        end;
        if HasConflicts then
          Result := ioMergedWithConflicts
        else
          Result := ioSuccess;
        Exit;
      end;
    end;
  end;

  ForceDirectories(GetTargetTranslationsPath);
  if not MoveDirectorySafe(CloneDir, TargetDir) then
  begin
    ErrorMsg := 'Could not move project to ' + TargetDir;
    Exit;
  end;
  Result := ioSuccess;
end;

function CloneAndImport(const CloneURL, Token: string;
  DupAction: TDuplicateAction;
  out ProjectName: string; out ErrorMsg: string): TImportOutcome;
var
  TempDir, TempCloneDir, AuthURL, RepoName: string;
  OutText, ErrText: string;
  ExitCode: Integer;
  Outcome: TImportOutcome;
begin
  Result      := ioError;
  ProjectName := '';
  ErrorMsg    := '';

  { Repo name from URL (last path component, strip .git) }
  RepoName := ExtractFileName(ExcludeTrailingPathDelimiter(CloneURL));
  if LowerCase(ExtractFileExt(RepoName)) = '.git' then
    RepoName := ChangeFileExt(RepoName, '');

  { Inject token into HTTPS URL for authentication }
  if Token <> '' then
    AuthURL := StringReplace(CloneURL, 'https://', 'https://' + Token + '@', [])
  else
    AuthURL := CloneURL;

  TempDir      := GetTempDir + 'bttw_server_' + TempTag;
  TempCloneDir := IncludeTrailingPathDelimiter(TempDir) + RepoName;
  ForceDirectories(TempDir);

  if not RunCommandCapture('git', ['clone', AuthURL, TempCloneDir],
    '', OutText, ErrText, ExitCode) or (ExitCode <> 0) then
  begin
    ErrorMsg := 'Clone failed: ' + Trim(ErrText);
    Cleanup(TempDir);
    Exit;
  end;

  Outcome := ImportClonedRepo(TempCloneDir, RepoName, DupAction,
    ProjectName, ErrorMsg);

  { Clean up temp dir unless ImportClonedRepo moved CloneDir (ioSuccess / ioMergedWithConflicts) }
  if (Outcome = ioError) or (Outcome = ioDuplicateExists) then
    Cleanup(TempDir)
  else
    Cleanup(TempDir);   { always clean temp root; repo was moved out already }

  Result := Outcome;
end;

end.
