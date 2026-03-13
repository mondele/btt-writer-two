unit USFMExporter;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes;

function ExportProjectToUSFM(const ProjectDir, SourceContentDir, OutputPath: string;
  out ErrorMsg: string): Boolean;

implementation

uses
  fpjson, jsonparser, ProjectManager, ProjectCreator, AppLog;

function ReadBookTitle(const ProjectDir: string): string;
var
  TitlePath: string;
  SL: TStringList;
begin
  Result := '';
  TitlePath := IncludeTrailingPathDelimiter(ProjectDir) + 'front' +
    DirectorySeparator + 'title.txt';
  if not FileExists(TitlePath) then
    Exit;
  SL := TStringList.Create;
  try
    SL.LoadFromFile(TitlePath);
    Result := Trim(SL.Text);
  finally
    SL.Free;
  end;
end;

function ExportProjectToUSFM(const ProjectDir, SourceContentDir, OutputPath: string;
  out ErrorMsg: string): Boolean;
var
  Proj: TProject;
  Output: TStringList;
  BookCode, BookTitle, ResourceID: string;
  I, J: Integer;
  Ch: string;
  ChunkContent: string;
begin
  Result := False;
  ErrorMsg := '';

  Proj := TProject.Create(ProjectDir);
  try
    if Proj.BookCode = '' then
    begin
      ErrorMsg := 'Project has no book code in manifest.';
      Exit;
    end;

    BookCode := UpperCase(Proj.BookCode);
    ResourceID := Proj.ResourceType;
    if ResourceID = '' then
      ResourceID := 'ulb';

    Proj.LoadContent(SourceContentDir);

    BookTitle := ReadBookTitle(ProjectDir);
    if BookTitle = '' then
      BookTitle := CanonicalBookName(Proj.BookCode);
    if BookTitle = '' then
      BookTitle := BookCode;

    Output := TStringList.Create;
    try
      { USFM header }
      Output.Add('\id ' + BookCode + ' ' + ResourceID);
      Output.Add('\ide usfm');
      Output.Add('\h ' + BookTitle);
      Output.Add('\toc1 ' + BookTitle);
      Output.Add('\toc2 ' + BookTitle);
      Output.Add('\toc3 ' + LowerCase(Proj.BookCode));
      Output.Add('\mt ' + BookTitle);
      Output.Add('');

      if Proj.Book <> nil then
      begin
        for I := 0 to Proj.Book.Chapters.Count - 1 do
        begin
          Ch := Proj.Book.Chapters[I].ID;
          { Skip the 'front' pseudo-chapter }
          if LowerCase(Ch) = 'front' then
            Continue;

          Output.Add('\c ' + Ch);
          Output.Add('\p');

          for J := 0 to Proj.Book.Chapters[I].Chunks.Count - 1 do
          begin
            ChunkContent := Trim(Proj.Book.Chapters[I].Chunks[J].Content);
            if ChunkContent <> '' then
              Output.Add(ChunkContent);
          end;
          Output.Add('');
        end;
      end;

      try
        Output.SaveToFile(OutputPath);
        Result := True;
        LogFmt(llInfo, 'USFM exported to: %s', [OutputPath]);
      except
        on E: Exception do
        begin
          ErrorMsg := 'Failed to write USFM file: ' + E.Message;
          Exit;
        end;
      end;
    finally
      Output.Free;
    end;
  finally
    Proj.Free;
  end;
end;

end.
