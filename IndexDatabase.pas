unit IndexDatabase;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TSourceLanguageInfo = record
    ID: Integer;
    Slug: string;       { e.g. 'en', 'ru', 'es-419' }
    Name: string;       { e.g. 'English', 'Русский' }
    Direction: string;  { 'ltr' or 'rtl' }
  end;
  TSourceLanguageArray = array of TSourceLanguageInfo;

  TTargetLanguageInfo = record
    ID: Integer;
    Slug: string;
    Name: string;
    AnglicizedName: string;
    Direction: string;
    Region: string;
    IsGateway: Boolean;
  end;
  TTargetLanguageArray = array of TTargetLanguageInfo;

  TBookInfo = record
    ProjectID: Integer;
    Slug: string;       { e.g. 'mat', 'gen', 'psa' }
    Name: string;       { e.g. 'Matthew', 'Genesis' }
    Sort: Integer;      { canonical order: 1-39 OT, 40-66 NT }
    CategorySlug: string;  { 'bible-nt', 'bible-ot', 'ta' }
  end;
  TBookInfoArray = array of TBookInfo;

  TResourceInfo = record
    ResourceID: Integer;
    Slug: string;       { e.g. 'ulb', 'udb', 'tn', 'tq', 'tw' }
    Name: string;       { e.g. 'Unlocked Literal Bible' }
    ResType: string;    { 'book', 'help', 'dict' }
    CheckingLevel: string;
    Version: string;
    SourceLangSlug: string;  { from joined source_language }
    SourceLangName: string;
  end;
  TResourceInfoArray = array of TResourceInfo;

  { Wraps the index.sqlite catalog for querying available languages,
    books, and resources. }
  TIndexDatabase = class
  private
    FDBPath: string;
    FDB: Pointer;  { sqlite3 handle }
    function QueryRows(const ASQL: string): TStringList;
  public
    constructor Create(const ADBPath: string);
    destructor Destroy; override;

    { List all source languages that have at least one resource. }
    function ListSourceLanguages: TSourceLanguageArray;

    { List all target languages. Optionally filter by partial name match. }
    function ListTargetLanguages(const AFilter: string = ''): TTargetLanguageArray;

    { List books available for a source language, filtered by category.
      CategorySlug: 'bible-nt', 'bible-ot', or '' for all. }
    function ListBooks(const ASourceLangSlug, ACategorySlug: string): TBookInfoArray;

    { List source text resources available for a given book across all
      source languages. Only includes text resources (ulb, udb, etc.),
      not notes/questions. }
    function ListSourceTexts(const ABookSlug: string): TResourceInfoArray;

    { List all resources for a specific book in a specific source language. }
    function ListResources(const ASourceLangSlug, ABookSlug: string): TResourceInfoArray;

    { Check if a specific .tsrc entry exists. Returns the slug
      ({lang}_{book}_{res}) or '' if not found. }
    function ResourceExists(const ALangSlug, ABookSlug, AResSlug: string): Boolean;

    property DBPath: string read FDBPath;
  end;

{ Find and open the index database. Extracts from bundled zip if needed.
  Returns nil if not available. }
function OpenIndexDatabase: TIndexDatabase;

{ Get the path where the index.sqlite should be stored. }
function GetIndexDatabasePath: string;

{ Ensure the index.sqlite exists in the data directory, extracting from
  the bundled zip if necessary. Returns True if available. }
function EnsureIndexDatabase: Boolean;

implementation

uses
  Zipper,
  sqlite3, sqlite3dyn,
  DataPaths, AppLog;

function GetIndexDatabasePath: string;
begin
  Result := IncludeTrailingPathDelimiter(GetDataPath) + 'index' +
    DirectorySeparator + 'index.sqlite';
end;

function FindBundledZipPath: string;
var
  InstallPath, DevPath: string;
begin
  { Check install location first }
  InstallPath := GetBundledResourceContainersZipPath;
  if FileExists(InstallPath) then
    Exit(InstallPath);

  { Dev-mode fallback: .claude/assets/ relative to executable }
  DevPath := ExtractFilePath(ParamStr(0)) + '.claude' + DirectorySeparator +
    'assets' + DirectorySeparator + 'resource_containers.zip';
  if FileExists(DevPath) then
    Exit(DevPath);

  Result := '';
end;

function EnsureIndexDatabase: Boolean;
var
  DBPath, ZipPath, DestDir: string;
  Unzipper: TUnZipper;
begin
  Result := False;
  DBPath := GetIndexDatabasePath;
  if FileExists(DBPath) then
    Exit(True);

  ZipPath := FindBundledZipPath;
  if ZipPath = '' then
  begin
    LogWarn('No bundled resource_containers.zip found');
    Exit(False);
  end;

  DestDir := ExtractFileDir(DBPath);
  ForceDirectories(DestDir);

  LogFmt(llInfo, 'Extracting index.sqlite from %s to %s', [ZipPath, DestDir]);

  Unzipper := TUnZipper.Create;
  try
    Unzipper.FileName := ZipPath;
    Unzipper.OutputPath := DestDir;
    Unzipper.Flat := True;  { strip directory structure — just get the file }
    Unzipper.Files.Add('index.sqlite');
    try
      Unzipper.UnZipAllFiles;
    except
      on E: Exception do
      begin
        LogFmt(llError, 'Failed to extract index.sqlite: %s', [E.Message]);
        Exit(False);
      end;
    end;
  finally
    Unzipper.Free;
  end;

  Result := FileExists(DBPath);
  if Result then
    LogInfo('index.sqlite extracted successfully')
  else
    LogWarn('index.sqlite extraction produced no file');
end;

function OpenIndexDatabase: TIndexDatabase;
var
  DBPath: string;
begin
  Result := nil;
  if not EnsureIndexDatabase then
    Exit;
  DBPath := GetIndexDatabasePath;
  try
    Result := TIndexDatabase.Create(DBPath);
  except
    on E: Exception do
    begin
      LogFmt(llError, 'Failed to open index database: %s', [E.Message]);
      Result := nil;
    end;
  end;
end;

{ ---- TIndexDatabase ---- }

constructor TIndexDatabase.Create(const ADBPath: string);
var
  RC: Integer;
begin
  inherited Create;
  FDBPath := ADBPath;
  FDB := nil;

  InitializeSQLite;

  RC := sqlite3_open(PAnsiChar(AnsiString(ADBPath)), @FDB);
  if RC <> SQLITE_OK then
  begin
    if FDB <> nil then
    begin
      LogFmt(llError, 'sqlite3_open failed: %s', [sqlite3_errmsg(FDB)]);
      sqlite3_close(FDB);
      FDB := nil;
    end;
    raise Exception.CreateFmt('Cannot open index database: %s', [ADBPath]);
  end;
  LogFmt(llInfo, 'Opened index database: %s', [ADBPath]);
end;

destructor TIndexDatabase.Destroy;
begin
  if FDB <> nil then
  begin
    sqlite3_close(FDB);
    FDB := nil;
  end;
  inherited Destroy;
end;

function TIndexDatabase.QueryRows(const ASQL: string): TStringList;
var
  Stmt: Pointer;
  RC, ColCount, I: Integer;
  Row: string;
begin
  Result := TStringList.Create;
  Stmt := nil;
  RC := sqlite3_prepare_v2(FDB, PAnsiChar(AnsiString(ASQL)), -1, @Stmt, nil);
  if RC <> SQLITE_OK then
  begin
    LogFmt(llError, 'SQL prepare failed: %s — %s', [sqlite3_errmsg(FDB), ASQL]);
    Exit;
  end;
  try
    ColCount := sqlite3_column_count(Stmt);
    while sqlite3_step(Stmt) = SQLITE_ROW do
    begin
      Row := '';
      for I := 0 to ColCount - 1 do
      begin
        if I > 0 then
          Row := Row + '|';
        Row := Row + string(sqlite3_column_text(Stmt, I));
      end;
      Result.Add(Row);
    end;
  finally
    sqlite3_finalize(Stmt);
  end;
end;

function SplitPipe(const S: string; Index: Integer): string;
var
  P, Start, Idx: Integer;
begin
  Result := '';
  Idx := 0;
  Start := 1;
  for P := 1 to Length(S) do
  begin
    if S[P] = '|' then
    begin
      if Idx = Index then
      begin
        Result := Copy(S, Start, P - Start);
        Exit;
      end;
      Inc(Idx);
      Start := P + 1;
    end;
  end;
  if Idx = Index then
    Result := Copy(S, Start, Length(S) - Start + 1);
end;

function TIndexDatabase.ListSourceLanguages: TSourceLanguageArray;
var
  Rows: TStringList;
  I: Integer;
begin
  SetLength(Result, 0);
  Rows := QueryRows(
    'SELECT DISTINCT sl.id, sl.slug, sl.name, sl.direction ' +
    'FROM source_language sl ' +
    'JOIN project p ON p.source_language_id = sl.id ' +
    'JOIN resource r ON r.project_id = p.id ' +
    'ORDER BY sl.name');
  try
    SetLength(Result, Rows.Count);
    for I := 0 to Rows.Count - 1 do
    begin
      Result[I].ID := StrToIntDef(SplitPipe(Rows[I], 0), 0);
      Result[I].Slug := SplitPipe(Rows[I], 1);
      Result[I].Name := SplitPipe(Rows[I], 2);
      Result[I].Direction := SplitPipe(Rows[I], 3);
    end;
  finally
    Rows.Free;
  end;
end;

function TIndexDatabase.ListTargetLanguages(const AFilter: string): TTargetLanguageArray;
var
  Rows: TStringList;
  SQL: string;
  I: Integer;
begin
  SetLength(Result, 0);
  SQL := 'SELECT id, slug, name, anglicized_name, direction, region, is_gateway_language ' +
         'FROM target_language';
  if AFilter <> '' then
    SQL := SQL + ' WHERE name LIKE ''%' + StringReplace(AFilter, '''', '''''', [rfReplaceAll]) +
           '%'' OR slug LIKE ''%' + StringReplace(AFilter, '''', '''''', [rfReplaceAll]) +
           '%'' OR anglicized_name LIKE ''%' + StringReplace(AFilter, '''', '''''', [rfReplaceAll]) + '%''';
  SQL := SQL + ' ORDER BY name';
  if AFilter <> '' then
    SQL := SQL + ' LIMIT 200';

  Rows := QueryRows(SQL);
  try
    SetLength(Result, Rows.Count);
    for I := 0 to Rows.Count - 1 do
    begin
      Result[I].ID := StrToIntDef(SplitPipe(Rows[I], 0), 0);
      Result[I].Slug := SplitPipe(Rows[I], 1);
      Result[I].Name := SplitPipe(Rows[I], 2);
      Result[I].AnglicizedName := SplitPipe(Rows[I], 3);
      Result[I].Direction := SplitPipe(Rows[I], 4);
      Result[I].Region := SplitPipe(Rows[I], 5);
      Result[I].IsGateway := SplitPipe(Rows[I], 6) = '1';
    end;
  finally
    Rows.Free;
  end;
end;

function TIndexDatabase.ListBooks(const ASourceLangSlug, ACategorySlug: string): TBookInfoArray;
var
  Rows: TStringList;
  SQL: string;
  I: Integer;
begin
  SetLength(Result, 0);
  SQL := 'SELECT p.id, p.slug, p.name, p.sort, c.slug ' +
         'FROM project p ' +
         'JOIN source_language sl ON p.source_language_id = sl.id ' +
         'LEFT JOIN category c ON p.category_id = c.id ' +
         'WHERE sl.slug = ''' + StringReplace(ASourceLangSlug, '''', '''''', [rfReplaceAll]) + '''';
  if ACategorySlug <> '' then
    SQL := SQL + ' AND c.slug = ''' + StringReplace(ACategorySlug, '''', '''''', [rfReplaceAll]) + '''';
  SQL := SQL + ' ORDER BY p.sort, p.name';

  Rows := QueryRows(SQL);
  try
    SetLength(Result, Rows.Count);
    for I := 0 to Rows.Count - 1 do
    begin
      Result[I].ProjectID := StrToIntDef(SplitPipe(Rows[I], 0), 0);
      Result[I].Slug := SplitPipe(Rows[I], 1);
      Result[I].Name := SplitPipe(Rows[I], 2);
      Result[I].Sort := StrToIntDef(SplitPipe(Rows[I], 3), 0);
      Result[I].CategorySlug := SplitPipe(Rows[I], 4);
    end;
  finally
    Rows.Free;
  end;
end;

function TIndexDatabase.ListSourceTexts(const ABookSlug: string): TResourceInfoArray;
var
  Rows: TStringList;
  SQL: string;
  I: Integer;
begin
  SetLength(Result, 0);
  SQL := 'SELECT r.id, r.slug, r.name, r.type, r.checking_level, r.version, ' +
         'sl.slug, sl.name ' +
         'FROM resource r ' +
         'JOIN project p ON r.project_id = p.id ' +
         'JOIN source_language sl ON p.source_language_id = sl.id ' +
         'WHERE p.slug = ''' + StringReplace(ABookSlug, '''', '''''', [rfReplaceAll]) + '''' +
         ' AND r.slug IN (''ulb'',''udb'',''avd'',''ayt'',''blv'',''bpb'',''cuv'',''f10'',' +
         '''nav'',''rlv'',''tbi'',''ugnt'',''uhb'',''vol1'',''vol2'',''vol3'')' +
         ' ORDER BY sl.name, r.slug';

  Rows := QueryRows(SQL);
  try
    SetLength(Result, Rows.Count);
    for I := 0 to Rows.Count - 1 do
    begin
      Result[I].ResourceID := StrToIntDef(SplitPipe(Rows[I], 0), 0);
      Result[I].Slug := SplitPipe(Rows[I], 1);
      Result[I].Name := SplitPipe(Rows[I], 2);
      Result[I].ResType := SplitPipe(Rows[I], 3);
      Result[I].CheckingLevel := SplitPipe(Rows[I], 4);
      Result[I].Version := SplitPipe(Rows[I], 5);
      Result[I].SourceLangSlug := SplitPipe(Rows[I], 6);
      Result[I].SourceLangName := SplitPipe(Rows[I], 7);
    end;
  finally
    Rows.Free;
  end;
end;

function TIndexDatabase.ListResources(const ASourceLangSlug, ABookSlug: string): TResourceInfoArray;
var
  Rows: TStringList;
  SQL: string;
  I: Integer;
begin
  SetLength(Result, 0);
  SQL := 'SELECT r.id, r.slug, r.name, r.type, r.checking_level, r.version, ' +
         'sl.slug, sl.name ' +
         'FROM resource r ' +
         'JOIN project p ON r.project_id = p.id ' +
         'JOIN source_language sl ON p.source_language_id = sl.id ' +
         'WHERE sl.slug = ''' + StringReplace(ASourceLangSlug, '''', '''''', [rfReplaceAll]) + '''' +
         ' AND p.slug = ''' + StringReplace(ABookSlug, '''', '''''', [rfReplaceAll]) + '''' +
         ' ORDER BY r.slug';

  Rows := QueryRows(SQL);
  try
    SetLength(Result, Rows.Count);
    for I := 0 to Rows.Count - 1 do
    begin
      Result[I].ResourceID := StrToIntDef(SplitPipe(Rows[I], 0), 0);
      Result[I].Slug := SplitPipe(Rows[I], 1);
      Result[I].Name := SplitPipe(Rows[I], 2);
      Result[I].ResType := SplitPipe(Rows[I], 3);
      Result[I].CheckingLevel := SplitPipe(Rows[I], 4);
      Result[I].Version := SplitPipe(Rows[I], 5);
      Result[I].SourceLangSlug := SplitPipe(Rows[I], 6);
      Result[I].SourceLangName := SplitPipe(Rows[I], 7);
    end;
  finally
    Rows.Free;
  end;
end;

function TIndexDatabase.ResourceExists(const ALangSlug, ABookSlug, AResSlug: string): Boolean;
var
  Rows: TStringList;
begin
  Rows := QueryRows(
    'SELECT 1 FROM resource r ' +
    'JOIN project p ON r.project_id = p.id ' +
    'JOIN source_language sl ON p.source_language_id = sl.id ' +
    'WHERE sl.slug = ''' + StringReplace(ALangSlug, '''', '''''', [rfReplaceAll]) + '''' +
    ' AND p.slug = ''' + StringReplace(ABookSlug, '''', '''''', [rfReplaceAll]) + '''' +
    ' AND r.slug = ''' + StringReplace(AResSlug, '''', '''''', [rfReplaceAll]) + '''');
  try
    Result := Rows.Count > 0;
  finally
    Rows.Free;
  end;
end;

end.
