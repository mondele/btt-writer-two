unit ProjectScanner;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, fpjson, jsonparser, DataPaths, ProjectCreator;

type
  TProjectSummary = record
    DirName: string;
    FullPath: string;
    BookCode: string;
    BookName: string;
    TargetLangCode: string;
    TargetLangName: string;
    ResourceType: string;
    TotalChunks: Integer;
    FinishedChunks: Integer;
  end;

  TProjectSummaryList = array of TProjectSummary;

{ Scan targetTranslations/ and return a summary for each valid project }
function ScanProjects: TProjectSummaryList;

{ Find the source content directory for a project in library/resource_containers/ }
function FindSourceContentDir(const Summary: TProjectSummary): string;

{ Find the English ULB content directory for a given book code }
function FindEnglishULBContentDir(const ABookCode: string): string;

implementation

function CountChunkFiles(const ProjectDir: string): Integer;
var
  SearchRec: TSearchRec;
  ChapterDir: string;
  InnerRec: TSearchRec;
begin
  Result := 0;
  if FindFirst(IncludeTrailingPathDelimiter(ProjectDir) + '*', faDirectory, SearchRec) = 0 then
  begin
    try
      repeat
        if (SearchRec.Name = '.') or (SearchRec.Name = '..') then
          Continue;
        if (SearchRec.Attr and faDirectory) = 0 then
          Continue;
        if SearchRec.Name[1] = '.' then
          Continue;

        ChapterDir := IncludeTrailingPathDelimiter(ProjectDir) + SearchRec.Name;
        if FindFirst(IncludeTrailingPathDelimiter(ChapterDir) + '*.txt', faAnyFile, InnerRec) = 0 then
        begin
          try
            repeat
              Inc(Result);
            until FindNext(InnerRec) <> 0;
          finally
            FindClose(InnerRec);
          end;
        end;
      until FindNext(SearchRec) <> 0;
    finally
      FindClose(SearchRec);
    end;
  end;
end;

function ReadManifestSummary(const ProjectDir: string; out Summary: TProjectSummary): Boolean;
var
  ManifestPath: string;
  SL: TStringList;
  JSONData: TJSONData;
  Manifest: TJSONObject;
  TargetLang: TJSONObject;
  Arr: TJSONArray;
  Node: TJSONData;
begin
  Result := False;
  ManifestPath := IncludeTrailingPathDelimiter(ProjectDir) + 'manifest.json';
  if not FileExists(ManifestPath) then
    Exit;

  SL := TStringList.Create;
  try
    SL.LoadFromFile(ManifestPath);
    JSONData := GetJSON(SL.Text);
    if not (JSONData is TJSONObject) then
    begin
      JSONData.Free;
      Exit;
    end;
    Manifest := TJSONObject(JSONData);
    try
      Summary.FullPath := IncludeTrailingPathDelimiter(ProjectDir);

      { Target language }
      Node := Manifest.FindPath('target_language');
      if Node is TJSONObject then
      begin
        TargetLang := TJSONObject(Node);
        Summary.TargetLangCode := TargetLang.Get('id', '');
        Summary.TargetLangName := TargetLang.Get('name', '');
      end;

      { Project }
      Node := Manifest.FindPath('project.id');
      if Node <> nil then
        Summary.BookCode := Node.AsString;
      Node := Manifest.FindPath('project.name');
      if Node <> nil then
        Summary.BookName := Node.AsString;

      { Resource type }
      Node := Manifest.FindPath('resource.id');
      if Node <> nil then
        Summary.ResourceType := Node.AsString;

      { Count finished chunks }
      Node := Manifest.FindPath('finished_chunks');
      if Node is TJSONArray then
      begin
        Arr := TJSONArray(Node);
        Summary.FinishedChunks := Arr.Count;
      end
      else
        Summary.FinishedChunks := 0;

      { Estimate total chunks by counting .txt files in chapter dirs }
      Summary.TotalChunks := CountChunkFiles(ProjectDir);

      Result := (Summary.BookCode <> '') and (Summary.TargetLangCode <> '') and
        IsCanonicalBibleBookCode(Summary.BookCode);
    finally
      Manifest.Free;
    end;
  finally
    FreeAndNil(SL);
  end;
end;

function ScanProjects: TProjectSummaryList;
var
  BasePath: string;
  SearchRec: TSearchRec;
  Summary: TProjectSummary;
  Count: Integer;
begin
  SetLength(Result, 0);
  Count := 0;
  BasePath := GetTargetTranslationsPath;

  if not DirectoryExists(BasePath) then
    Exit;

  if FindFirst(BasePath + '*', faDirectory, SearchRec) = 0 then
  begin
    try
      repeat
        if (SearchRec.Name = '.') or (SearchRec.Name = '..') then
          Continue;
        if (SearchRec.Attr and faDirectory) = 0 then
          Continue;

        Summary := Default(TProjectSummary);
        Summary.DirName := SearchRec.Name;
        if ReadManifestSummary(BasePath + SearchRec.Name, Summary) then
        begin
          Inc(Count);
          SetLength(Result, Count);
          Result[Count - 1] := Summary;
        end;
      until FindNext(SearchRec) <> 0;
    finally
      FindClose(SearchRec);
    end;
  end;
end;

function FindSourceContentDir(const Summary: TProjectSummary): string;
var
  LibPath, ContentDir, DirName: string;
  SearchRec: TSearchRec;
  LangCode, BookCode, ResType: string;
  Parts: TStringArray;
begin
  Result := '';
  LibPath := GetLibraryPath;

  if not DirectoryExists(LibPath) then
    Exit;

  if FindFirst(LibPath + '*', faDirectory, SearchRec) = 0 then
  begin
    try
      repeat
        if (SearchRec.Name = '.') or (SearchRec.Name = '..') then
          Continue;
        if (SearchRec.Attr and faDirectory) = 0 then
          Continue;

        DirName := SearchRec.Name;
        Parts := DirName.Split('_');
        if Length(Parts) <> 3 then
          Continue;

        LangCode := Parts[0];
        BookCode := Parts[1];
        ResType := Parts[2];

        if (BookCode = Summary.BookCode) and
           ((ResType = 'ulb') or (ResType = Summary.ResourceType)) then
        begin
          ContentDir := IncludeTrailingPathDelimiter(LibPath + SearchRec.Name) + 'content';
          if DirectoryExists(ContentDir) then
          begin
            Result := ContentDir;
            { Prefer English ULB }
            if LangCode = 'en' then
              Exit;
          end;
        end;
      until FindNext(SearchRec) <> 0;
    finally
      FindClose(SearchRec);
    end;
  end;
end;

function FindEnglishULBContentDir(const ABookCode: string): string;
var
  DirPath: string;
begin
  DirPath := GetLibraryPath + 'en_' + ABookCode + '_ulb';
  Result := IncludeTrailingPathDelimiter(DirPath) + 'content';
  if not DirectoryExists(Result) then
    Result := '';
end;

end.
