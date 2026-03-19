unit ResourceContainer;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, BibleBook;

type
  TResourceContainer = class
  private
    FLanguageCode: string;
    FBookCode: string;
    FResourceType: string;
    FBasePath: string;
    FDirection: string;  { 'ltr' or 'rtl', read from package.json }
    FBook: TBook;
  public
    constructor Create(const ALangCode, ABookCode, AResType, ABasePath: string);
    destructor Destroy; override;

    { Parse a directory name in format langCode_bookCode_resourceType.
      Returns True if valid, outputs the three parts. }
    class function ParseDirName(const DirName: string;
      out LangCode, BookCode, ResType: string): Boolean;

    { Load structure from toc.yml and content from .usx files }
    procedure Load;

    { Read language direction from package.json in the resource container
      directory. Call after setting BasePath. Falls back to 'ltr'. }
    procedure LoadDirection;

    property LanguageCode: string read FLanguageCode;
    property BookCode: string read FBookCode;
    property ResourceType: string read FResourceType;
    property BasePath: string read FBasePath;
    property Direction: string read FDirection write FDirection;
    property Book: TBook read FBook;
  end;

{ Read the language direction from a resource container's package.json.
  Returns 'ltr' or 'rtl'. Falls back to 'ltr' if not found. }
function ReadResourceDirection(const ResourceDir: string): string;

implementation

uses
  fpjson, jsonparser;

function ReadResourceDirection(const ResourceDir: string): string;
var
  PkgPath: string;
  SL: TStringList;
  Data: TJSONData;
  Node: TJSONData;
begin
  Result := 'ltr';
  PkgPath := IncludeTrailingPathDelimiter(ResourceDir) + 'package.json';
  if not FileExists(PkgPath) then
    Exit;
  SL := TStringList.Create;
  try
    SL.LoadFromFile(PkgPath);
    try
      Data := GetJSON(SL.Text);
      if Data is TJSONObject then
      begin
        Node := TJSONObject(Data).FindPath('language.direction');
        if (Node <> nil) and (Trim(Node.AsString) <> '') then
          Result := LowerCase(Trim(Node.AsString));
      end;
      Data.Free;
    except
      { Invalid JSON — fall back to ltr }
    end;
  finally
    SL.Free;
  end;
end;

constructor TResourceContainer.Create(const ALangCode, ABookCode, AResType, ABasePath: string);
begin
  inherited Create;
  FLanguageCode := ALangCode;
  FBookCode := ABookCode;
  FResourceType := AResType;
  FBasePath := ABasePath;
  FDirection := 'ltr';
  FBook := TBook.Create(ABookCode, AResType);
end;

destructor TResourceContainer.Destroy;
begin
  FreeAndNil(FBook);
  inherited Destroy;
end;

class function TResourceContainer.ParseDirName(const DirName: string;
  out LangCode, BookCode, ResType: string): Boolean;
var
  Parts: TStringArray;
begin
  Parts := DirName.Split('_');
  Result := Length(Parts) = 3;
  if Result then
  begin
    LangCode := Parts[0];
    BookCode := Parts[1];
    ResType := Parts[2];
    Result := (LangCode <> '') and (BookCode <> '') and (ResType <> '');
  end;
end;

procedure TResourceContainer.LoadDirection;
begin
  if FBasePath <> '' then
    FDirection := ReadResourceDirection(FBasePath)
  else
    FDirection := 'ltr';
end;

procedure TResourceContainer.Load;
var
  ContentDir: string;
begin
  ContentDir := IncludeTrailingPathDelimiter(FBasePath) + 'content';
  if not DirectoryExists(ContentDir) then
  begin
    WriteLn('Content directory not found: ', ContentDir);
    Exit;
  end;
  FBook.LoadFromToc(ContentDir);
  FBook.LoadContent(ContentDir, '.usx');
  LoadDirection;
end;

end.
