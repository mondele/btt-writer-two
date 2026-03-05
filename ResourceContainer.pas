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

    property LanguageCode: string read FLanguageCode;
    property BookCode: string read FBookCode;
    property ResourceType: string read FResourceType;
    property BasePath: string read FBasePath;
    property Book: TBook read FBook;
  end;

implementation

constructor TResourceContainer.Create(const ALangCode, ABookCode, AResType, ABasePath: string);
begin
  inherited Create;
  FLanguageCode := ALangCode;
  FBookCode := ABookCode;
  FResourceType := AResType;
  FBasePath := ABasePath;
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
end;

end.
