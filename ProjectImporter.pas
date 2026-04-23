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

{ Import a USFM file as a new text project.
  TargetLangCode is used for both the directory name and the manifest.
  Source text is assumed to be English ULB (standard chunk structure).
  On success, ProjectName receives the canonical directory name. }
function ImportUSFMFile(const FilePath, TargetLangCode: string;
  DupAction: TDuplicateAction;
  out ProjectName: string; out ErrorMsg: string): TImportOutcome;

implementation

uses
  SysUtils, Classes, DateUtils,
  TStudioPackage, GitUtils, DataPaths, ProjectScanner,
  USFMUtils, ProjectData, BibleBook, BibleChapter, CanonBooks, AppLog;

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

{ Write parsed USFM verses into chunk .txt files in ProjectDir, using the
  English ULB toc for chunk boundary mapping. }
procedure WriteUSFMVersesToChunks(const ParseResult: TUSFMParseResult;
  const ProjectDir, EnglishULBContentDir: string);
var
  ULBBook         : TBook;
  ULBChapter      : TChapter;
  I, J            : Integer;
  ChapterNum      : Integer;
  VerseNum        : Integer;
  ChunkStart      : Integer;
  NextChunkStart  : Integer;
  ChDir, ChunkPath, ChunkContent, ChapterStr: string;
  SL              : TStringList;
begin
  ULBBook := nil;
  if EnglishULBContentDir <> '' then
  begin
    ULBBook := TBook.Create('', 'ulb');
    ULBBook.LoadFromToc(EnglishULBContentDir);
  end;
  try
    for I := 0 to Length(ParseResult.Verses) - 1 do
    begin
      ChapterNum := ParseResult.Verses[I].Chapter;
      VerseNum   := ParseResult.Verses[I].Verse;
      if ChapterNum <= 0 then Continue;

      ChapterStr := Format('%.2d', [ChapterNum]);
      ChDir := IncludeTrailingPathDelimiter(ProjectDir) + ChapterStr;
      ForceDirectories(ChDir);

      ChunkStart := VerseNum;
      if ULBBook <> nil then
      begin
        ULBChapter := ULBBook.GetChapter(ChapterStr);
        if ULBChapter <> nil then
        begin
          ChunkStart := VerseNum;
          for J := 0 to ULBChapter.Chunks.Count - 1 do
          begin
            if not TryStrToInt(ULBChapter.Chunks[J].Name, ChunkStart) then
              Continue;
            if J < ULBChapter.Chunks.Count - 1 then
            begin
              if TryStrToInt(ULBChapter.Chunks[J + 1].Name, NextChunkStart) then
              begin
                if (VerseNum >= ChunkStart) and (VerseNum < NextChunkStart) then
                  Break;
              end;
            end
            else
            begin
              if VerseNum >= ChunkStart then Break;
            end;
          end;
        end;
      end;

      ChunkPath    := IncludeTrailingPathDelimiter(ChDir) + Format('%.2d', [ChunkStart]) + '.txt';
      ChunkContent := ParseResult.Verses[I].Content;
      SL := TStringList.Create;
      try
        if FileExists(ChunkPath) then
          SL.LoadFromFile(ChunkPath);
        if Trim(SL.Text) = '' then
          SL.Text := ChunkContent
        else
          SL.Text := SL.Text + ChunkContent;
        SL.SaveToFile(ChunkPath);
      finally
        SL.Free;
      end;
    end;
  finally
    FreeAndNil(ULBBook);
  end;
end;

function ImportUSFMFile(const FilePath, TargetLangCode: string;
  DupAction: TDuplicateAction;
  out ProjectName: string; out ErrorMsg: string): TImportOutcome;
var
  ParseResult : TUSFMParseResult;
  BookCode    : string;
  SourceOpt   : TSourceTextOption;
  ExistingDir : string;
  NewProjectDir: string;
  SourceDir   : string;
  TempDir     : string;
  TempProjDir : string;
  HasConflicts: Boolean;
  GitErr      : string;
  OutText, ErrText: string;
  ExitCode    : Integer;
begin
  Result      := ioError;
  ProjectName := '';
  ErrorMsg    := '';

  if not ParseUSFMFile(FilePath, ParseResult, ErrorMsg) then
    Exit;

  BookCode := LowerCase(Trim(ParseResult.BookID));
  if not IsCanonicalBibleBookCode(BookCode) then
  begin
    ErrorMsg := 'Unrecognized book code: ' + ParseResult.BookID;
    Exit;
  end;

  if Trim(TargetLangCode) = '' then
  begin
    ErrorMsg := 'Target language code is required.';
    Exit;
  end;

  { Build source text option using English ULB }
  SourceOpt := Default(TSourceTextOption);
  SourceOpt.SourceLangCode := 'en';
  SourceOpt.BookCode       := BookCode;
  SourceOpt.ResourceID     := 'ulb';

  ExistingDir := IncludeTrailingPathDelimiter(GetTargetTranslationsPath) +
    Trim(TargetLangCode) + '_' + BookCode + '_text_reg';

  if DirectoryExists(ExistingDir) then
  begin
    if DupAction = daNone then
    begin
      ProjectName := ExtractFileName(ExcludeTrailingPathDelimiter(ExistingDir));
      Result := ioDuplicateExists;
      Exit;
    end;

    if DupAction = daOverwrite then
    begin
      RunCommandCapture('bash', ['-lc', 'rm -rf ' + ShellQuote(ExistingDir)],
        '', OutText, ErrText, ExitCode);
    end
    else if DupAction = daMerge then
    begin
      TempDir     := GetTempDir + 'bttw_usfm_' + TempTag;
      TempProjDir := IncludeTrailingPathDelimiter(TempDir) +
        Trim(TargetLangCode) + '_' + BookCode + '_text_reg';
      ForceDirectories(TempProjDir);
      RunCommandCapture('git', ['-C', TempProjDir, 'init'],
        '', OutText, ErrText, ExitCode);
      SourceDir := FindEnglishULBContentDir(BookCode);
      WriteUSFMVersesToChunks(ParseResult, TempProjDir, SourceDir);
      EnsureProjectCommitted(TempProjDir, GitErr);
      if not MergeImportedProject(ExistingDir, TempProjDir, HasConflicts, ErrorMsg) then
      begin
        Cleanup(TempDir);
        Exit;
      end;
      Cleanup(TempDir);
      ProjectName := ExtractFileName(ExcludeTrailingPathDelimiter(ExistingDir));
      LogInfo('USFM import merged: ' + ProjectName);
      if HasConflicts then
        Result := ioMergedWithConflicts
      else
        Result := ioSuccess;
      Exit;
    end;
  end;

  { Create the project (new or after overwrite) }
  if not CreateProjectFromSource(Trim(TargetLangCode), Trim(TargetLangCode),
    SourceOpt, ptText, NewProjectDir, ErrorMsg) then
    Exit;

  SourceDir := FindEnglishULBContentDir(BookCode);
  WriteUSFMVersesToChunks(ParseResult, NewProjectDir, SourceDir);
  CommitProjectChanges(NewProjectDir, 'Import from USFM', GitErr);

  ProjectName := ExtractFileName(ExcludeTrailingPathDelimiter(NewProjectDir));
  LogInfo('USFM import: ' + ProjectName);
  Result := ioSuccess;
end;

end.
