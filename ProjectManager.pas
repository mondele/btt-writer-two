unit ProjectManager;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, fpjson, jsonparser,
  BibleBook, BookUsfm, Globals;

type
  TProject = class
  private
    FProjectDir: string;
    FManifestPath: string;
    FManifest: TJSONObject;
    FBook: TBook;

    FTargetLanguageCode: string;
    FBookCode: string;
    FResourceType: string;

    FUSFMHeader: TUSFMBookHeader;
    FCanonicalMonolithic: Boolean;

    procedure LoadManifest;
    procedure SaveManifest;
    function GetFinishedChunks: TJSONArray;
    function GetProjectDisplayName: string;
  public
    constructor Create(const AProjectDir: string);
    destructor Destroy; override;

    { Load project structure from a source toc.yml, then load content
      from the project's own .txt chunk files, OR — if the canonical
      monolithic USFM file exists — load that instead and skip the
      per-chunk merge. Legacy v1 projects (no monolithic file) get
      bootstrapped: chunks are read, then the monolithic file is
      written so subsequent opens take the fast canonical path. }
    procedure LoadContent(const SourceContentDir: string);

    { Save any dirty chunks back to project directory }
    procedure SaveContent;

    { Chunk finished state }
    function IsFinished(const ChapterID, ChunkName: string): Boolean;
    procedure MarkFinished(const ChapterID, ChunkName: string);
    procedure MarkUnfinished(const ChapterID, ChunkName: string);

    { Contributors }
    procedure AddContributor(const AName: string);
    procedure RemoveContributor(const AName: string);

    { Source info from manifest }
    function GetSourceLanguageCode: string;
    function GetSourceResourceType: string;
    function GetTargetLanguageDirection: string;
    procedure SetSourceTranslation(const ALangCode, AResType: string);

    property ProjectDir: string read FProjectDir;
    property TargetLanguageCode: string read FTargetLanguageCode;
    property BookCode: string read FBookCode;
    property ResourceType: string read FResourceType;
    property Book: TBook read FBook;
    property USFMHeader: TUSFMBookHeader read FUSFMHeader write FUSFMHeader;
    property CanonicalMonolithic: Boolean read FCanonicalMonolithic;
  end;

implementation

constructor TProject.Create(const AProjectDir: string);
begin
  inherited Create;
  FProjectDir := IncludeTrailingPathDelimiter(AProjectDir);
  FManifestPath := FProjectDir + 'manifest.json';
  FManifest := nil;
  FBook := nil;

  if FileExists(FManifestPath) then
    LoadManifest;
end;

destructor TProject.Destroy;
begin
  FreeAndNil(FBook);
  FreeAndNil(FManifest);
  inherited Destroy;
end;

procedure TProject.LoadManifest;
var
  SL: TStringList;
  JSONData: TJSONData;
  TargetLang: TJSONObject;
begin
  FreeAndNil(FManifest);

  SL := TStringList.Create;
  try
    SL.LoadFromFile(FManifestPath);
    JSONData := GetJSON(SL.Text);
    if JSONData is TJSONObject then
      FManifest := TJSONObject(JSONData)
    else
    begin
      JSONData.Free;
      Exit;
    end;
  finally
    FreeAndNil(SL);
  end;

  { Extract key fields }
  if FManifest.FindPath('target_language') is TJSONObject then
  begin
    TargetLang := TJSONObject(FManifest.FindPath('target_language'));
    FTargetLanguageCode := TargetLang.Get('id', '');
  end;

  FBookCode := '';
  if FManifest.FindPath('project.id') <> nil then
    FBookCode := FManifest.FindPath('project.id').AsString;

  FResourceType := '';
  if FManifest.FindPath('resource.id') <> nil then
    FResourceType := FManifest.FindPath('resource.id').AsString;

  if Verbose then
    WriteLn('Loaded manifest: lang=', FTargetLanguageCode,
            ' book=', FBookCode, ' type=', FResourceType);
end;

procedure TProject.SaveManifest;
var
  SL: TStringList;
begin
  if FManifest = nil then
    Exit;

  SL := TStringList.Create;
  try
    SL.Text := FManifest.FormatJSON;
    SL.SaveToFile(FManifestPath);
  finally
    FreeAndNil(SL);
  end;
end;

function TProject.GetFinishedChunks: TJSONArray;
var
  Node: TJSONData;
begin
  Result := nil;
  if FManifest = nil then
    Exit;

  Node := FManifest.FindPath('finished_chunks');
  if Node is TJSONArray then
    Result := TJSONArray(Node);
end;

function TProject.GetProjectDisplayName: string;
var
  Node: TJSONData;
begin
  Result := FBookCode;
  if FManifest = nil then Exit;
  Node := FManifest.FindPath('project.name');
  if (Node <> nil) and (Trim(Node.AsString) <> '') then
    Result := Trim(Node.AsString);
end;

procedure TProject.LoadContent(const SourceContentDir: string);
var
  MonoPath: string;
  LoadedHeader: TUSFMBookHeader;
begin
  FreeAndNil(FBook);
  FBook := TBook.Create(FBookCode, FResourceType);
  FCanonicalMonolithic := False;

  MonoPath := MonolithicUSFMPath(FProjectDir, FBookCode, FTargetLanguageCode);
  if (MonoPath <> '') and FileExists(MonoPath) then
  begin
    if LoadMonolithicUSFM(MonoPath, FBook, LoadedHeader) then
    begin
      FUSFMHeader := LoadedHeader;
      FCanonicalMonolithic := True;
      if Verbose then
        WriteLn('Loaded monolithic USFM: ', MonoPath);
      Exit;
    end;
    { Failed to parse — fall through to legacy and overwrite below. }
    FreeAndNil(FBook);
    FBook := TBook.Create(FBookCode, FResourceType);
  end;

  { Legacy v1 path: chunk files are canonical. }
  FBook.LoadFromToc(SourceContentDir);
  FBook.LoadContent(FProjectDir, '.txt');

  { Bootstrap: build and persist a monolithic file from the chunks we
    just loaded, so the next open takes the canonical path. }
  if MonoPath <> '' then
  begin
    FUSFMHeader := DefaultUSFMHeader(FBookCode, GetProjectDisplayName);
    try
      SaveMonolithicUSFM(MonoPath, FBook, FUSFMHeader);
      FCanonicalMonolithic := True;
      if Verbose then
        WriteLn('Bootstrapped monolithic USFM from chunks: ', MonoPath);
    except
      on E: Exception do
        if Verbose then
          WriteLn('Failed to bootstrap monolithic USFM: ', E.Message);
    end;
  end;
end;

procedure TProject.SaveContent;
begin
  if FBook <> nil then
    FBook.SaveAllDirty(FProjectDir, '.txt');
end;

function TProject.IsFinished(const ChapterID, ChunkName: string): Boolean;
var
  Arr: TJSONArray;
  Key: string;
  I: Integer;
begin
  Result := False;
  Arr := GetFinishedChunks;
  if Arr = nil then
    Exit;

  Key := ChapterID + '-' + ChunkName;
  for I := 0 to Arr.Count - 1 do
    if Arr.Strings[I] = Key then
      Exit(True);
end;

procedure TProject.MarkFinished(const ChapterID, ChunkName: string);
var
  Arr: TJSONArray;
  Key: string;
begin
  if FManifest = nil then
    Exit;

  Key := ChapterID + '-' + ChunkName;

  if IsFinished(ChapterID, ChunkName) then
    Exit;

  Arr := GetFinishedChunks;
  if Arr = nil then
  begin
    Arr := TJSONArray.Create;
    FManifest.Add('finished_chunks', Arr);
  end;

  Arr.Add(Key);
  SaveManifest;
end;

procedure TProject.MarkUnfinished(const ChapterID, ChunkName: string);
var
  Arr: TJSONArray;
  Key: string;
  I: Integer;
begin
  Arr := GetFinishedChunks;
  if Arr = nil then
    Exit;

  Key := ChapterID + '-' + ChunkName;
  for I := Arr.Count - 1 downto 0 do
    if Arr.Strings[I] = Key then
    begin
      Arr.Delete(I);
      SaveManifest;
      Exit;
    end;
end;

procedure TProject.AddContributor(const AName: string);
var
  Arr: TJSONArray;
  Node: TJSONData;
  I: Integer;
begin
  if FManifest = nil then
    Exit;

  Node := FManifest.FindPath('translators');
  if Node is TJSONArray then
    Arr := TJSONArray(Node)
  else
  begin
    Arr := TJSONArray.Create;
    FManifest.Add('translators', Arr);
  end;

  { Check for duplicates }
  for I := 0 to Arr.Count - 1 do
    if Arr.Strings[I] = AName then
      Exit;

  Arr.Add(AName);
  SaveManifest;
end;

procedure TProject.RemoveContributor(const AName: string);
var
  Arr: TJSONArray;
  Node: TJSONData;
  I: Integer;
begin
  if FManifest = nil then
    Exit;

  Node := FManifest.FindPath('translators');
  if not (Node is TJSONArray) then
    Exit;

  Arr := TJSONArray(Node);
  for I := Arr.Count - 1 downto 0 do
    if Arr.Strings[I] = AName then
    begin
      Arr.Delete(I);
      SaveManifest;
      Exit;
    end;
end;

function TProject.GetSourceLanguageCode: string;
var
  Arr: TJSONArray;
  Node: TJSONData;
begin
  Result := '';
  if FManifest = nil then
    Exit;

  Node := FManifest.FindPath('source_translations');
  if not (Node is TJSONArray) then
    Exit;

  Arr := TJSONArray(Node);
  if (Arr.Count > 0) and (Arr.Items[0] is TJSONObject) then
    Result := TJSONObject(Arr.Items[0]).Get('language_id', '');
end;

function TProject.GetSourceResourceType: string;
var
  Arr: TJSONArray;
  Node: TJSONData;
begin
  Result := '';
  if FManifest = nil then
    Exit;

  Node := FManifest.FindPath('source_translations');
  if not (Node is TJSONArray) then
    Exit;

  Arr := TJSONArray(Node);
  if (Arr.Count > 0) and (Arr.Items[0] is TJSONObject) then
    Result := TJSONObject(Arr.Items[0]).Get('resource_id', '');
end;

function TProject.GetTargetLanguageDirection: string;
var
  Node: TJSONData;
begin
  Result := 'ltr';
  if FManifest = nil then
    Exit;
  Node := FManifest.FindPath('target_language.direction');
  if (Node <> nil) and (Trim(Node.AsString) <> '') then
    Result := LowerCase(Trim(Node.AsString));
end;

procedure TProject.SetSourceTranslation(const ALangCode, AResType: string);
var
  Arr: TJSONArray;
  Obj: TJSONObject;
  Node: TJSONData;
begin
  if FManifest = nil then
    Exit;

  Node := FManifest.FindPath('source_translations');
  if Node is TJSONArray then
    Arr := TJSONArray(Node)
  else
  begin
    Arr := TJSONArray.Create;
    FManifest.Add('source_translations', Arr);
  end;

  if (Arr.Count > 0) and (Arr.Items[0] is TJSONObject) then
  begin
    Obj := TJSONObject(Arr.Items[0]);
    Obj.Delete('language_id');
    Obj.Add('language_id', ALangCode);
    Obj.Delete('resource_id');
    Obj.Add('resource_id', AResType);
  end
  else
  begin
    Obj := TJSONObject.Create;
    Obj.Add('language_id', ALangCode);
    Obj.Add('resource_id', AResType);
    Arr.Add(Obj);
  end;

  SaveManifest;
end;

end.
