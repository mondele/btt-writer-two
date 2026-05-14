unit LegalTexts;

{$mode objfpc}{$H+}

{ Legal / informational documents shown in Terms-of-Use and Settings.

  The bodies of these documents are long-form markdown stored as files
  under cge/locale/<lang>/<basename>.md (with cge/locale/en/<basename>.md
  as the source-of-truth fallback). Loading is on demand — the file is
  read each time the dialog is opened. Translators edit markdown files
  with their preferred editor instead of wrestling multi-line msgid
  blocks in a .po file.

  Only the short window titles remain as resourcestrings; those still
  travel through the regular extract-pot / mine pipeline. }

interface

resourcestring
  rsLicenseTitle = 'Creative Commons Attribution-ShareAlike 4.0 International';
  rsGuidelinesTitle = 'Translation Guidelines';
  rsStatementTitle = 'Statement of Faith';
  rsSoftwareTitle = 'Software Licenses';
  rsLegalTextMissing = 'Document not available (file missing).';

const
  LEGAL_LICENSE        = 'license-agreement';
  LEGAL_GUIDELINES     = 'translation-guidelines';
  LEGAL_STATEMENT      = 'statement-of-faith';
  LEGAL_SOFTWARE       = 'software-licenses';

function LoadLegalText(const BaseName: string): string;

implementation

uses
  Classes, SysUtils, AppSettings;

function LegalCandidatePaths(const Lang, BaseName: string): TStringArray;
var
  ExeDir: string;
begin
  ExeDir := ExtractFilePath(ParamStr(0));
  if ExeDir = '' then
    ExeDir := GetCurrentDir + DirectorySeparator;
  SetLength(Result, 2);
  Result[0] := ExeDir + 'cge' + DirectorySeparator + 'locale' +
               DirectorySeparator + Lang + DirectorySeparator + BaseName + '.md';
  Result[1] := ExeDir + '..' + DirectorySeparator + 'cge' + DirectorySeparator +
               'locale' + DirectorySeparator + Lang + DirectorySeparator + BaseName + '.md';
end;

function TryLoadFile(const Path: string; out Body: string): Boolean;
var
  SL: TStringList;
begin
  Result := False;
  Body := '';
  if not FileExists(Path) then Exit;
  SL := TStringList.Create;
  try
    SL.LoadFromFile(Path);
    Body := SL.Text;
    Result := True;
  finally
    SL.Free;
  end;
end;

function LoadLegalText(const BaseName: string): string;
var
  Lang, Path: string;
begin
  Result := '';
  Lang := GetInterfaceLanguage;
  if Lang = '' then Lang := 'en';

  { Preferred language. }
  for Path in LegalCandidatePaths(Lang, BaseName) do
    if TryLoadFile(Path, Result) then Exit;

  { English fallback. }
  if Lang <> 'en' then
    for Path in LegalCandidatePaths('en', BaseName) do
      if TryLoadFile(Path, Result) then Exit;

  Result := rsLegalTextMissing;
end;

end.
