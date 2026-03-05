unit ProjectCreator;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, fpjson;

type
  TSourceTextOption = record
    SourceDir: string;
    SourceLangCode: string;
    SourceLangName: string;
    BookCode: string;
    BookName: string;
    ResourceID: string;
    ResourceName: string;
  end;

  TSourceTextOptionList = array of TSourceTextOption;

function ListSourceTextOptions: TSourceTextOptionList;
function FindSourceTextOption(const SourceLangCode, BookCode, ResourceID: string;
  out Opt: TSourceTextOption): Boolean;
function CreateProjectFromSource(const TargetLangCode, TargetLangName: string;
  const SourceOpt: TSourceTextOption; out ProjectDir: string;
  out ErrorMsg: string): Boolean;

implementation

uses
  Process, jsonparser, DataPaths;

function LoadJSONFile(const APath: string): TJSONObject;
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

function RunGit(const WorkDir: string; const Args: array of string;
  out ErrorMsg: string): Boolean;
var
  P: TProcess;
  OutS, ErrS: TStringStream;
  I: Integer;
begin
  Result := False;
  ErrorMsg := '';

  P := TProcess.Create(nil);
  OutS := TStringStream.Create('');
  ErrS := TStringStream.Create('');
  try
    P.Executable := 'git';
    P.CurrentDirectory := WorkDir;
    P.Options := [poUsePipes, poWaitOnExit];
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

    if P.Output.NumBytesAvailable > 0 then
      OutS.CopyFrom(P.Output, P.Output.NumBytesAvailable);
    if P.Stderr.NumBytesAvailable > 0 then
      ErrS.CopyFrom(P.Stderr, P.Stderr.NumBytesAvailable);

    if P.ExitStatus = 0 then
      Exit(True);

    ErrorMsg := Trim(ErrS.DataString);
    if ErrorMsg = '' then
      ErrorMsg := Trim(OutS.DataString);
    if ErrorMsg = '' then
      ErrorMsg := 'git exited with status ' + IntToStr(P.ExitStatus);
  finally
    ErrS.Free;
    OutS.Free;
    P.Free;
  end;
end;

function ListSourceTextOptions: TSourceTextOptionList;
var
  BasePath: string;
  SR: TSearchRec;
  Count: Integer;
  DirPath, PackagePath: string;
  Obj, LangObj, ProjObj, ResObj: TJSONObject;
  Opt: TSourceTextOption;
begin
  SetLength(Result, 0);
  Count := 0;
  BasePath := GetLibraryPath;

  if not DirectoryExists(BasePath) then
    Exit;

  if FindFirst(IncludeTrailingPathDelimiter(BasePath) + '*', faDirectory, SR) <> 0 then
    Exit;
  try
    repeat
      if (SR.Name = '.') or (SR.Name = '..') then
        Continue;
      if (SR.Attr and faDirectory) = 0 then
        Continue;

      DirPath := IncludeTrailingPathDelimiter(BasePath) + SR.Name;
      PackagePath := IncludeTrailingPathDelimiter(DirPath) + 'package.json';
      if not FileExists(PackagePath) then
        Continue;

      Obj := LoadJSONFile(PackagePath);
      if Obj = nil then
        Continue;
      try
        if not (Obj.Find('language') is TJSONObject) then
          Continue;
        if not (Obj.Find('project') is TJSONObject) then
          Continue;
        if not (Obj.Find('resource') is TJSONObject) then
          Continue;

        LangObj := TJSONObject(Obj.Find('language'));
        ProjObj := TJSONObject(Obj.Find('project'));
        ResObj := TJSONObject(Obj.Find('resource'));

        { Only show likely source text resources for now }
        if ResObj.Get('slug', '') = '' then
          Continue;
        if (ResObj.Get('slug', '') <> 'ulb') and (ResObj.Get('slug', '') <> 'udb') then
          Continue;

        Opt.SourceDir := DirPath;
        Opt.SourceLangCode := LangObj.Get('slug', '');
        Opt.SourceLangName := LangObj.Get('name', '');
        Opt.BookCode := ProjObj.Get('slug', '');
        Opt.BookName := ProjObj.Get('name', '');
        Opt.ResourceID := ResObj.Get('slug', '');
        Opt.ResourceName := ResObj.Get('name', '');

        if (Opt.SourceLangCode = '') or (Opt.BookCode = '') then
          Continue;

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

function CopyFileSimple(const SrcPath, DstPath: string): Boolean;
var
  Src, Dst: TFileStream;
begin
  Result := False;
  if not FileExists(SrcPath) then
    Exit;
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

function FindSourceTextOption(const SourceLangCode, BookCode, ResourceID: string;
  out Opt: TSourceTextOption): Boolean;
var
  L: TSourceTextOptionList;
  I: Integer;
begin
  Result := False;
  L := ListSourceTextOptions;
  for I := 0 to Length(L) - 1 do
    if (CompareText(L[I].SourceLangCode, SourceLangCode) = 0) and
       (CompareText(L[I].BookCode, BookCode) = 0) and
       (CompareText(L[I].ResourceID, ResourceID) = 0) then
    begin
      Opt := L[I];
      Exit(True);
    end;
end;

function FindLicenseFile(const SourceDir: string): string;
begin
  Result := IncludeTrailingPathDelimiter(SourceDir) + 'LICENSE.md';
  if not FileExists(Result) then
    Result := '';
end;

function BuildManifestJSON(const TargetLangCode, TargetLangName: string;
  const SourceOpt: TSourceTextOption): TJSONObject;
var
  TargetObj, ProjectObj, TypeObj, ResourceObj, GeneratorObj, SourceObj: TJSONObject;
  SourcesArr, TranslatorsArr, FinishedArr: TJSONArray;
begin
  Result := TJSONObject.Create;
  Result.Add('package_version', 8);
  Result.Add('format', 'usfm');

  GeneratorObj := TJSONObject.Create;
  GeneratorObj.Add('name', 'btt-writer-two');
  GeneratorObj.Add('build', 'codex');
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
  ProjectObj.Add('id', SourceOpt.BookCode);
  ProjectObj.Add('name', SourceOpt.BookName);
  Result.Add('project', ProjectObj);

  TypeObj := TJSONObject.Create;
  TypeObj.Add('id', 'text');
  TypeObj.Add('name', 'Text');
  Result.Add('type', TypeObj);

  ResourceObj := TJSONObject.Create;
  ResourceObj.Add('id', 'reg');
  ResourceObj.Add('name', 'Regular');
  Result.Add('resource', ResourceObj);

  SourcesArr := TJSONArray.Create;
  SourceObj := TJSONObject.Create;
  SourceObj.Add('language_id', SourceOpt.SourceLangCode);
  SourceObj.Add('resource_id', SourceOpt.ResourceID);
  SourceObj.Add('checking_level', '3');
  SourceObj.Add('date_modified', FormatDateTime('yyyy"-"mm"-"dd"T"hh":"nn":"ss', Now));
  SourceObj.Add('version', '1');
  SourcesArr.Add(SourceObj);
  Result.Add('source_translations', SourcesArr);

  TranslatorsArr := TJSONArray.Create;
  TranslatorsArr.Add('Raphael');
  Result.Add('translators', TranslatorsArr);

  FinishedArr := TJSONArray.Create;
  Result.Add('finished_chunks', FinishedArr);
end;

function CreateProjectFromSource(const TargetLangCode, TargetLangName: string;
  const SourceOpt: TSourceTextOption; out ProjectDir: string;
  out ErrorMsg: string): Boolean;
var
  DirName, FullDir, ManifestPath, LicenseSrc, LicenseDst: string;
  Manifest: TJSONObject;
  SL: TStringList;
  GitErr: string;
begin
  Result := False;
  ErrorMsg := '';
  ProjectDir := '';

  DirName := TargetLangCode + '_' + SourceOpt.BookCode + '_text_reg';
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

  Manifest := BuildManifestJSON(TargetLangCode, TargetLangName, SourceOpt);
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

  LicenseSrc := FindLicenseFile(SourceOpt.SourceDir);
  if LicenseSrc <> '' then
  begin
    LicenseDst := IncludeTrailingPathDelimiter(FullDir) + 'LICENSE.md';
    CopyFileSimple(LicenseSrc, LicenseDst);
  end;

  if not RunGit(FullDir, ['init'], GitErr) then
  begin
    ErrorMsg := 'Project created but git init failed: ' + GitErr;
    ProjectDir := FullDir;
    Exit(False);
  end;
  RunGit(FullDir, ['config', 'user.name', 'BTT Writer Two'], GitErr);
  RunGit(FullDir, ['config', 'user.email', 'bttwriter2@local'], GitErr);
  if not RunGit(FullDir, ['add', 'manifest.json', 'LICENSE.md'], GitErr) then
    if not RunGit(FullDir, ['add', 'manifest.json'], GitErr) then
    begin
      ErrorMsg := 'Project created but git add failed: ' + GitErr;
      ProjectDir := FullDir;
      Exit(False);
    end;

  if not RunGit(FullDir, ['commit', '-m', 'Initial project scaffold'], GitErr) then
  begin
    ErrorMsg := 'Project created but git commit failed: ' + GitErr;
    ProjectDir := FullDir;
    Exit(False);
  end;

  ProjectDir := FullDir;
  Result := True;
end;

end.
