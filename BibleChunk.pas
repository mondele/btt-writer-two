unit BibleChunk;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes;

type
  TChunk = class
  private
    FName: string;
    FContent: string;
    FExistsOnDisk: Boolean;
    FDirty: Boolean;
    procedure SetContent(const AContent: string);
  public
    constructor Create(const AName: string; AExistsOnDisk: Boolean = False);
    function IsEquivalentTo(Other: TChunk): Boolean;
    procedure LoadFromFile(const APath: string);
    procedure SaveToFile(const APath: string);

    property Name: string read FName;
    property Content: string read FContent write SetContent;
    property ExistsOnDisk: Boolean read FExistsOnDisk;
    property Dirty: Boolean read FDirty;
  end;

implementation

constructor TChunk.Create(const AName: string; AExistsOnDisk: Boolean);
begin
  inherited Create;
  FName := AName;
  FExistsOnDisk := AExistsOnDisk;
  FContent := '';
  FDirty := False;
end;

procedure TChunk.SetContent(const AContent: string);
begin
  if FContent <> AContent then
  begin
    FContent := AContent;
    FDirty := True;
  end;
end;

function TChunk.IsEquivalentTo(Other: TChunk): Boolean;
begin
  Result := (FName = Other.FName) and (FExistsOnDisk = Other.FExistsOnDisk);
end;

procedure TChunk.LoadFromFile(const APath: string);
var
  SL: TStringList;
begin
  if not FileExists(APath) then
  begin
    FExistsOnDisk := False;
    FContent := '';
    Exit;
  end;

  SL := TStringList.Create;
  try
    SL.LoadFromFile(APath);
    FContent := SL.Text;
    FExistsOnDisk := True;
    FDirty := False;
  finally
    FreeAndNil(SL);
  end;
end;

procedure TChunk.SaveToFile(const APath: string);
var
  Dir: string;
  SL: TStringList;
begin
  Dir := ExtractFilePath(APath);
  if (Dir <> '') and not DirectoryExists(Dir) then
    ForceDirectories(Dir);

  SL := TStringList.Create;
  try
    SL.Text := FContent;
    SL.SaveToFile(APath);
    FExistsOnDisk := True;
    FDirty := False;
  finally
    FreeAndNil(SL);
  end;
end;

end.
