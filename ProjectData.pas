{$mode objfpc}{$H+}
unit ProjectData;

{ LCL-free project data layer shared by both the LCL desktop app and the
  CGE UI.  Contains type definitions, index queries, source-text extraction,
  and project creation.  No Forms / Controls / Dialogs dependency. }

interface

uses
  SysUtils, Classes, fpjson;

{ ── Types ───────────────────────────────────────────────────────────────── }

type
  TBookOption = record
    Code: string;
    Name: string;
  end;
  TBookOptionList = array of TBookOption;

  TTargetLanguageOption = record
    Code: string;
    Name: string;
  end;
  TTargetLanguageOptionList = array of TTargetLanguageOption;

  TSourceTextOption = record
    SourceDir    : string;
    SourceLangCode: string;
    SourceLangName: string;
    BookCode     : string;
    BookName     : string;
    ResourceID   : string;
    ResourceName : string;
  end;
  TSourceTextOptionList = array of TSourceTextOption;

  TProjectTypeID = (ptText, ptNotes, ptQuestions);

{ ── Queries ─────────────────────────────────────────────────────────────── }

function ListTargetLanguagesFromIndex: TTargetLanguageOptionList;
function ListBooksFromIndex:           TBookOptionList;
function ListSourceTextOptionsForBookFromIndex(const BookCode: string): TSourceTextOptionList;
function ListSourceTextOptions: TSourceTextOptionList;
function FindSourceTextOption(const SourceLangCode, BookCode, ResourceID: string;
  out Opt: TSourceTextOption): Boolean;
function TextProjectExistsFor(const TargetLangCode, BookCode: string): Boolean;

{ ── Creation ─────────────────────────────────────────────────────────────── }

function EnsureSourceTextPresent(const SourceOpt: TSourceTextOption;
  out SourceDir, ErrorMsg: string): Boolean;
function CreateProjectFromSource(const TargetLangCode, TargetLangName: string;
  const SourceOpt: TSourceTextOption; AProjType: TProjectTypeID;
  out ProjectDir: string; out ErrorMsg: string): Boolean;
function CommitProjectChanges(const ProjectDir, CommitMsg: string;
  out ErrorMsg: string): Boolean;

implementation

uses
  Process, jsonparser,
  DataPaths, SourceExtractor, IndexDatabase, AppLog, GitUtils, CanonBooks;

const
  NON_GL_RESOURCE_ID   = 'reg';
  NON_GL_RESOURCE_NAME = 'Regular';
  PROJECT_TYPE_ID      = 'text';
  PROJECT_TYPE_NAME    = 'Text';

{ ── Internal helpers ─────────────────────────────────────────────────────── }

function LoadJSONFile(const APath: string): TJSONObject;
var
  SL  : TStringList;
  Data: TJSONData;
begin
  Result := nil;
  if not FileExists(APath) then Exit;
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

function RunGit(const WorkDir: string; const Args: array of string;
  out ErrorMsg: string): Boolean;
var
  P         : TProcess;
  OutS, ErrS: TStringStream;
  I         : Integer;
  Buf       : array[0..4095] of Byte;
  N         : LongInt;
begin
  Result   := False;
  ErrorMsg := '';
  P    := TProcess.Create(nil);
  OutS := TStringStream.Create('');
  ErrS := TStringStream.Create('');
  try
    P.Executable := 'git';
    P.CurrentDirectory := WorkDir;
    P.Options := [poUsePipes];
    for I := 0 to High(Args) do
      P.Parameters.Add(Args[I]);
    try
      P.Execute;
    except
      on E: Exception do
      begin
        ErrorMsg := E.Message;
        Exit(False);
      end;
    end;
    while P.Running do
    begin
      while P.Output.NumBytesAvailable > 0 do
      begin
        N := P.Output.Read(Buf, SizeOf(Buf));
        if N > 0 then OutS.WriteBuffer(Buf, N);
      end;
      while P.Stderr.NumBytesAvailable > 0 do
      begin
        N := P.Stderr.Read(Buf, SizeOf(Buf));
        if N > 0 then ErrS.WriteBuffer(Buf, N);
      end;
      Sleep(5);
    end;
    while P.Output.NumBytesAvailable > 0 do
    begin
      N := P.Output.Read(Buf, SizeOf(Buf));
      if N > 0 then OutS.WriteBuffer(Buf, N);
    end;
    while P.Stderr.NumBytesAvailable > 0 do
    begin
      N := P.Stderr.Read(Buf, SizeOf(Buf));
      if N > 0 then ErrS.WriteBuffer(Buf, N);
    end;
    if P.ExitStatus = 0 then Exit(True);
    ErrorMsg := Trim(ErrS.DataString);
    if ErrorMsg = '' then ErrorMsg := Trim(OutS.DataString);
    if ErrorMsg = '' then ErrorMsg := 'git exited with status ' + IntToStr(P.ExitStatus);
  finally
    ErrS.Free; OutS.Free; P.Free;
  end;
end;

function CopyFileSimple(const SrcPath, DstPath: string): Boolean;
var
  Src, Dst: TFileStream;
begin
  Result := False;
  if not FileExists(SrcPath) then Exit;
  Src := TFileStream.Create(SrcPath, fmOpenRead or fmShareDenyNone);
  try
    Dst := TFileStream.Create(DstPath, fmCreate);
    try
      Dst.CopyFrom(Src, 0);
      Result := True;
    finally
      Dst.Free;
    end;
  finally
    Src.Free;
  end;
end;

function FindLicenseFile(const SourceDir: string): string;
begin
  Result := IncludeTrailingPathDelimiter(SourceDir) + 'LICENSE.md';
  if not FileExists(Result) then Result := '';
end;

function ProjectTypeToManifest(AProjType: TProjectTypeID;
  out TypeID, TypeName, ResourceID, ResourceName, Format: string): Boolean;
begin
  Result := True;
  case AProjType of
    ptNotes: begin
      TypeID := 'tn'; TypeName := 'Notes';
      ResourceID := 'tn'; ResourceName := 'translationNotes'; Format := 'json';
    end;
    ptQuestions: begin
      TypeID := 'tq'; TypeName := 'Questions';
      ResourceID := 'tq'; ResourceName := 'translationQuestions'; Format := 'json';
    end;
  else begin
      TypeID := PROJECT_TYPE_ID; TypeName := PROJECT_TYPE_NAME;
      ResourceID := NON_GL_RESOURCE_ID; ResourceName := NON_GL_RESOURCE_NAME;
      Format := 'usfm';
    end;
  end;
end;

function BuildManifestJSON(const TargetLangCode, TargetLangName: string;
  const SourceOpt: TSourceTextOption; AProjType: TProjectTypeID): TJSONObject;
var
  TargetObj, ProjectObj, TypeObj, ResourceObj, GeneratorObj, SourceObj: TJSONObject;
  SourcesArr, TranslatorsArr, FinishedArr: TJSONArray;
  ProjectName: string;
  MTypeID, MTypeName, MResID, MResName, MFormat: string;
begin
  ProjectTypeToManifest(AProjType, MTypeID, MTypeName, MResID, MResName, MFormat);
  Result := TJSONObject.Create;
  Result.Add('package_version', 8);
  Result.Add('format', MFormat);

  GeneratorObj := TJSONObject.Create;
  GeneratorObj.Add('name', 'btt-writer-two');
  GeneratorObj.Add('build', 'cge');
  Result.Add('generator', GeneratorObj);

  TargetObj := TJSONObject.Create;
  TargetObj.Add('name', TargetLangName);
  TargetObj.Add('direction', 'ltr');
  TargetObj.Add('anglicized_name', TargetLangName);
  TargetObj.Add('region', '');
  TargetObj.Add('is_gateway_language', False);
  TargetObj.Add('id', TargetLangCode);
  Result.Add('target_language', TargetObj);

  ProjectObj := TJSONObject.Create;
  ProjectName := CanonicalBookName(SourceOpt.BookCode);
  if ProjectName = '' then ProjectName := Trim(SourceOpt.BookName);
  if ProjectName = '' then ProjectName := SourceOpt.BookCode;
  ProjectObj.Add('id', SourceOpt.BookCode);
  ProjectObj.Add('name', ProjectName);
  Result.Add('project', ProjectObj);

  TypeObj := TJSONObject.Create;
  TypeObj.Add('id', MTypeID);
  TypeObj.Add('name', MTypeName);
  Result.Add('type', TypeObj);

  ResourceObj := TJSONObject.Create;
  ResourceObj.Add('id', MResID);
  ResourceObj.Add('name', MResName);
  Result.Add('resource', ResourceObj);

  SourcesArr := TJSONArray.Create;
  SourceObj  := TJSONObject.Create;
  SourceObj.Add('language_id', SourceOpt.SourceLangCode);
  SourceObj.Add('resource_id', SourceOpt.ResourceID);
  SourceObj.Add('checking_level', '3');
  SourceObj.Add('date_modified',
    FormatDateTime('yyyy"-"mm"-"dd"T"hh":"nn":"ss', Now));
  SourceObj.Add('version', '1');
  SourcesArr.Add(SourceObj);
  Result.Add('source_translations', SourcesArr);

  TranslatorsArr := TJSONArray.Create;
  Result.Add('translators', TranslatorsArr);

  FinishedArr := TJSONArray.Create;
  Result.Add('finished_chunks', FinishedArr);
end;

function ResolveInstalledSourceDir(const SourceOpt: TSourceTextOption): string;
var
  Match: TSourceTextOption;
begin
  Result := '';
  if FindSourceTextOption(SourceOpt.SourceLangCode, SourceOpt.BookCode,
                          SourceOpt.ResourceID, Match) then
    Exit(Match.SourceDir);
  Result := IncludeTrailingPathDelimiter(GetLibraryPath) +
    LowerCase(Trim(SourceOpt.SourceLangCode)) + '_' +
    LowerCase(Trim(SourceOpt.BookCode))       + '_' +
    LowerCase(Trim(SourceOpt.ResourceID));
  if not FileExists(IncludeTrailingPathDelimiter(Result) + 'package.json') then
    Result := '';
end;

{ ── Public: queries ─────────────────────────────────────────────────────── }

function ListTargetLanguagesFromIndex: TTargetLanguageOptionList;
var
  DB   : TIndexDatabase;
  Langs: TTargetLanguageArray;
  I    : Integer;
begin
  SetLength(Result, 0);
  DB := OpenIndexDatabase;
  if DB = nil then Exit;
  try
    Langs := DB.ListTargetLanguages;
    SetLength(Result, Length(Langs));
    for I := 0 to High(Langs) do
    begin
      Result[I].Code := Langs[I].Slug;
      Result[I].Name := Langs[I].Name;
    end;
  finally
    DB.Free;
  end;
end;

function ListBooksFromIndex: TBookOptionList;
var
  DB       : TIndexDatabase;
  SrcLangs : TSourceLanguageArray;
  Books    : TBookInfoArray;
  Available: array[0..65] of Boolean;
  I, J, Count: Integer;
  Code     : string;
begin
  SetLength(Result, 0);
  DB := OpenIndexDatabase;
  if DB = nil then Exit;
  try
    SrcLangs := DB.ListSourceLanguages;
    for I := 0 to High(Available) do
      Available[I] := False;
    for I := 0 to High(SrcLangs) do
    begin
      Books := DB.ListBooks(SrcLangs[I].Slug, '');
      for J := 0 to High(Books) do
      begin
        Code := LowerCase(Trim(Books[J].Slug));
        for Count := 0 to High(CANON_BOOKS) do
          if Code = CANON_BOOKS[Count].Code then
          begin
            Available[Count] := True;
            Break;
          end;
      end;
    end;
    Count := 0;
    for I := 0 to High(CANON_BOOKS) do
      if Available[I] then
      begin
        Inc(Count);
        SetLength(Result, Count);
        Result[Count - 1].Code := CANON_BOOKS[I].Code;
        Result[Count - 1].Name := CANON_BOOKS[I].Name;
      end;
    if Count = 0 then
    begin
      SetLength(Result, Length(CANON_BOOKS));
      for I := 0 to High(CANON_BOOKS) do
      begin
        Result[I].Code := CANON_BOOKS[I].Code;
        Result[I].Name := CANON_BOOKS[I].Name;
      end;
    end;
  finally
    DB.Free;
  end;
end;

function ListSourceTextOptionsForBookFromIndex(const BookCode: string): TSourceTextOptionList;
var
  DB       : TIndexDatabase;
  Resources: TResourceInfoArray;
  I, Count : Integer;
  Opt      : TSourceTextOption;
  BookName : string;
begin
  SetLength(Result, 0);
  if Trim(BookCode) = '' then Exit;
  DB := OpenIndexDatabase;
  if DB = nil then Exit;
  try
    Resources := DB.ListSourceTexts(LowerCase(Trim(BookCode)));
    BookName  := CanonicalBookName(BookCode);
    Count := 0;
    for I := 0 to High(Resources) do
    begin
      Opt.SourceLangCode := Resources[I].SourceLangSlug;
      Opt.SourceLangName := Resources[I].SourceLangName;
      Opt.BookCode  := LowerCase(Trim(BookCode));
      Opt.BookName  := BookName;
      Opt.ResourceID   := Resources[I].Slug;
      Opt.ResourceName := Resources[I].Name;
      Opt.SourceDir := '';
      Inc(Count);
      SetLength(Result, Count);
      Result[Count - 1] := Opt;
    end;
  finally
    DB.Free;
  end;
end;

function ListSourceTextOptions: TSourceTextOptionList;
var
  BasePath, DirPath, PackagePath, ResourceSlug, ResourceType: string;
  SR       : TSearchRec;
  Count    : Integer;
  Obj, LangObj, ProjObj, ResObj: TJSONObject;
  Opt      : TSourceTextOption;
begin
  SetLength(Result, 0);
  Count    := 0;
  BasePath := GetLibraryPath;
  if not DirectoryExists(BasePath) then Exit;
  if FindFirst(IncludeTrailingPathDelimiter(BasePath) + '*', faDirectory, SR) <> 0 then
    Exit;
  try
    repeat
      if (SR.Name = '.') or (SR.Name = '..') then Continue;
      if (SR.Attr and faDirectory) = 0 then Continue;
      DirPath     := IncludeTrailingPathDelimiter(BasePath) + SR.Name;
      PackagePath := IncludeTrailingPathDelimiter(DirPath) + 'package.json';
      if not FileExists(PackagePath) then Continue;
      Obj := LoadJSONFile(PackagePath);
      if Obj = nil then Continue;
      try
        if not (Obj.Find('language') is TJSONObject) then Continue;
        if not (Obj.Find('project')  is TJSONObject) then Continue;
        if not (Obj.Find('resource') is TJSONObject) then Continue;
        LangObj := TJSONObject(Obj.Find('language'));
        ProjObj := TJSONObject(Obj.Find('project'));
        ResObj  := TJSONObject(Obj.Find('resource'));
        ResourceSlug := LowerCase(Trim(ResObj.Get('slug', '')));
        ResourceType := LowerCase(Trim(ResObj.Get('type', '')));
        if ResourceSlug = '' then Continue;
        if (ResourceSlug = 'tn') or (ResourceSlug = 'tq') then Continue;
        if (ResourceType <> '') and (ResourceType <> 'book') then Continue;
        Opt.SourceDir      := DirPath;
        Opt.SourceLangCode := LangObj.Get('slug', '');
        Opt.SourceLangName := LangObj.Get('name', '');
        Opt.BookCode       := ProjObj.Get('slug', '');
        Opt.BookName       := ProjObj.Get('name', '');
        Opt.ResourceID     := ResObj.Get('slug', '');
        Opt.ResourceName   := ResObj.Get('name', '');
        if (Opt.SourceLangCode = '') or (Opt.BookCode = '') then Continue;
        Inc(Count);
        SetLength(Result, Count);
        Result[Count - 1] := Opt;
      finally
        Obj.Free;
      end;
    until FindNext(SR) <> 0;
  finally
    FindClose(SR);
  end;
end;

function FindSourceTextOption(const SourceLangCode, BookCode, ResourceID: string;
  out Opt: TSourceTextOption): Boolean;
var
  L: TSourceTextOptionList;
  I: Integer;
begin
  Result := False;
  L := ListSourceTextOptions;
  for I := 0 to High(L) do
    if (CompareText(L[I].SourceLangCode, SourceLangCode) = 0) and
       (CompareText(L[I].BookCode,       BookCode)       = 0) and
       (CompareText(L[I].ResourceID,     ResourceID)     = 0) then
    begin
      Opt := L[I];
      Exit(True);
    end;
end;

function TextProjectExistsFor(const TargetLangCode, BookCode: string): Boolean;
var
  BasePath, DirName, DirPath: string;
  SR    : TSearchRec;
  Parts : TStringArray;
begin
  Result   := False;
  BasePath := GetTargetTranslationsPath;
  if not DirectoryExists(BasePath) then Exit;
  if FindFirst(BasePath + '*', faDirectory, SR) <> 0 then Exit;
  try
    repeat
      if (SR.Name = '.') or (SR.Name = '..') then Continue;
      if (SR.Attr and faDirectory) = 0 then Continue;
      DirName := SR.Name;
      Parts   := string(DirName).Split('_');
      if Length(Parts) >= 3 then
        if (CompareText(Parts[0], TargetLangCode) = 0) and
           (CompareText(Parts[1], BookCode)        = 0) and
           (CompareText(Parts[2], 'text')          = 0) then
        begin
          DirPath := IncludeTrailingPathDelimiter(BasePath + DirName);
          if FileExists(DirPath + 'manifest.json') then
            Exit(True);
        end;
    until FindNext(SR) <> 0;
  finally
    FindClose(SR);
  end;
end;

{ ── Public: creation ─────────────────────────────────────────────────────── }

function EnsureSourceTextPresent(const SourceOpt: TSourceTextOption;
  out SourceDir, ErrorMsg: string): Boolean;
var
  ZipPath, DestRoot, DestDir, TsrcSlug: string;
begin
  Result    := False;
  SourceDir := '';
  ErrorMsg  := '';

  SourceDir := ResolveInstalledSourceDir(SourceOpt);
  if SourceDir <> '' then Exit(True);

  ZipPath := SourceExtractor.FindBundledZipPath;
  if ZipPath = '' then
    ZipPath := GetBundledResourceContainersZipPath;
  if (ZipPath = '') or (not FileExists(ZipPath)) then
  begin
    ErrorMsg := 'Source text is not installed and bundled resource archive was not found.';
    Exit(False);
  end;

  TsrcSlug := LowerCase(Trim(SourceOpt.SourceLangCode)) + '_' +
              LowerCase(Trim(SourceOpt.BookCode))       + '_' +
              LowerCase(Trim(SourceOpt.ResourceID));
  DestRoot := GetLibraryPath;
  DestDir  := IncludeTrailingPathDelimiter(DestRoot) + TsrcSlug;

  if not ForceDirectories(DestDir) then
  begin
    ErrorMsg := 'Could not create source container directory: ' + DestDir;
    Exit(False);
  end;

  LogFmt(llInfo, 'Extracting source text: %s → %s', [TsrcSlug, DestDir]);

  if not ExtractTsrc(ZipPath, TsrcSlug, DestDir) then
  begin
    ErrorMsg := 'Failed to extract bundled source text: ' + TsrcSlug + '.tsrc';
    Exit(False);
  end;

  SourceDir := DestDir;
  Result    := True;
end;

function CreateProjectFromSource(const TargetLangCode, TargetLangName: string;
  const SourceOpt: TSourceTextOption; AProjType: TProjectTypeID;
  out ProjectDir: string; out ErrorMsg: string): Boolean;
var
  DirName, FullDir, ManifestPath, LicenseSrc, LicenseDst, SourceDir: string;
  MTypeID, MTypeName, MResID, MResName, MFormat: string;
  Manifest: TJSONObject;
  SL      : TStringList;
  GitErr  : string;
begin
  Result    := False;
  ErrorMsg  := '';
  ProjectDir := '';

  if not EnsureSourceTextPresent(SourceOpt, SourceDir, ErrorMsg) then
    Exit(False);

  ProjectTypeToManifest(AProjType, MTypeID, MTypeName, MResID, MResName, MFormat);
  DirName := TargetLangCode + '_' + SourceOpt.BookCode + '_' +
             MTypeID + '_' + MResID;
  FullDir := IncludeTrailingPathDelimiter(GetTargetTranslationsPath) + DirName;
  if DirectoryExists(FullDir) then
  begin
    ErrorMsg := 'Project already exists: ' + FullDir;
    Exit;
  end;
  if not ForceDirectories(FullDir) then
  begin
    ErrorMsg := 'Could not create project directory: ' + FullDir;
    Exit;
  end;

  Manifest := BuildManifestJSON(TargetLangCode, TargetLangName, SourceOpt, AProjType);
  try
    ManifestPath := IncludeTrailingPathDelimiter(FullDir) + 'manifest.json';
    SL := TStringList.Create;
    try
      SL.Text := Manifest.FormatJSON;
      SL.SaveToFile(ManifestPath);
    finally
      SL.Free;
    end;
  finally
    Manifest.Free;
  end;

  LicenseSrc := FindLicenseFile(SourceDir);
  if LicenseSrc <> '' then
  begin
    LicenseDst := IncludeTrailingPathDelimiter(FullDir) + 'LICENSE.md';
    CopyFileSimple(LicenseSrc, LicenseDst);
  end;

  if not RunGit(FullDir, ['init'], GitErr) then
  begin
    ErrorMsg   := 'Project created but git init failed: ' + GitErr;
    ProjectDir := FullDir;
    Exit(False);
  end;
  RunGit(FullDir, ['config', 'user.name',  'BTT Writer Two'],   GitErr);
  RunGit(FullDir, ['config', 'user.email', 'bttwriter2@local'], GitErr);
  if not RunGit(FullDir, ['add', 'manifest.json', 'LICENSE.md'], GitErr) then
    if not RunGit(FullDir, ['add', 'manifest.json'], GitErr) then
    begin
      ErrorMsg   := 'Project created but git add failed: ' + GitErr;
      ProjectDir := FullDir;
      Exit(False);
    end;
  if not RunGit(FullDir, ['commit', '-m', 'Initial project scaffold'], GitErr) then
  begin
    ErrorMsg   := 'Project created but git commit failed: ' + GitErr;
    ProjectDir := FullDir;
    Exit(False);
  end;

  ProjectDir := FullDir;
  Result     := True;
end;

function CommitProjectChanges(const ProjectDir, CommitMsg: string;
  out ErrorMsg: string): Boolean;
var
  OutText, ErrText: string;
  ExitCode        : Integer;
begin
  Result   := False;
  ErrorMsg := '';
  if not DirectoryExists(ProjectDir) then
  begin
    ErrorMsg := 'Project directory not found: ' + ProjectDir;
    Exit;
  end;
  if not RunCommandCapture('git', ['status', '--porcelain'], ProjectDir,
                           OutText, ErrText, ExitCode) then
  begin
    ErrorMsg := ErrText;
    Exit;
  end;
  if ExitCode <> 0 then
  begin
    ErrorMsg := Trim(ErrText);
    Exit;
  end;
  if Trim(OutText) = '' then Exit(True);

  if not RunGit(ProjectDir, ['add', '-A'], ErrorMsg) then Exit(False);
  if not RunGit(ProjectDir, ['commit', '-m', CommitMsg], ErrorMsg) then
  begin
    if Pos('nothing to commit', LowerCase(ErrorMsg)) > 0 then Exit(True);
    Exit(False);
  end;
  Result := True;
end;

end.
