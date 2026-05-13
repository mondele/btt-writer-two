unit LocaleManager;

{$mode objfpc}{$H+}

{ Runtime translation loader.

  Reads AppSettings.GetInterfaceLanguage, locates the matching .po file
  under cge/locale/<lang>/btt-writer.po (relative to the executable),
  and calls Translations.TranslateResourceStrings to swap msgid -> msgstr
  for all units in the running process.

  For 'en' (the source language) no .po is loaded — resourcestrings keep
  their literal source values.

  Locale directory resolution tries, in order:
    1. <exe-dir>/cge/locale/<lang>/btt-writer.po       (dev run from repo)
    2. <exe-dir>/../cge/locale/<lang>/btt-writer.po    (installed layout)
    3. <DATA PATH>/locale/<lang>/btt-writer.po         (user override)

  Returns the path actually loaded (empty string if no file was found or
  if the language was 'en' / unset). }

interface

type
  TLangArray = array of string;

function ApplyInterfaceLanguage: string;
function ListAvailableLanguages: TLangArray;

implementation

uses
  SysUtils, Classes, Translations, AppSettings, DataPaths, AppLog;

function CandidatePaths(const Lang: string): TLangArray;
var
  ExeDir: string;
begin
  ExeDir := ExtractFilePath(ParamStr(0));
  if ExeDir = '' then
    ExeDir := GetCurrentDir + DirectorySeparator;
  SetLength(Result, 3);
  Result[0] := ExeDir + 'cge' + DirectorySeparator + 'locale' + DirectorySeparator +
               Lang + DirectorySeparator + 'btt-writer.po';
  Result[1] := ExeDir + '..' + DirectorySeparator + 'cge' + DirectorySeparator +
               'locale' + DirectorySeparator + Lang + DirectorySeparator + 'btt-writer.po';
  Result[2] := IncludeTrailingPathDelimiter(GetDataPath) + 'locale' +
               DirectorySeparator + Lang + DirectorySeparator + 'btt-writer.po';
end;

function LocateLanguageFile(const Lang: string): string;
var
  Candidate: string;
begin
  Result := '';
  if (Lang = '') or (Lang = 'en') then Exit;
  for Candidate in CandidatePaths(Lang) do
    if FileExists(Candidate) then
    begin
      Result := Candidate;
      Exit;
    end;
end;

function ApplyInterfaceLanguage: string;
var
  Lang, POPath: string;
begin
  Result := '';
  Lang := GetInterfaceLanguage;
  if (Lang = '') or (Lang = 'en') then
  begin
    LogInfo('LocaleManager: interface language ' + Lang + ' — using source strings');
    Exit;
  end;

  POPath := LocateLanguageFile(Lang);
  if POPath = '' then
  begin
    LogWarn('LocaleManager: no .po file found for language "' + Lang + '"');
    Exit;
  end;

  try
    Translations.TranslateResourceStrings(POPath);
    LogInfo('LocaleManager: loaded ' + POPath);
    Result := POPath;
  except
    on E: Exception do
      LogError('LocaleManager: failed to load ' + POPath + ' — ' + E.Message);
  end;
end;

function ListAvailableLanguages: TLangArray;
var
  ExeDir, LocaleDir, Lang: string;
  SR: TSearchRec;
  Found: TStringList;
  I: Integer;
begin
  Result := nil;
  Found := TStringList.Create;
  try
    Found.Sorted := True;
    Found.Duplicates := dupIgnore;
    Found.Add('en');

    ExeDir := ExtractFilePath(ParamStr(0));
    if ExeDir = '' then
      ExeDir := GetCurrentDir + DirectorySeparator;
    LocaleDir := ExeDir + 'cge' + DirectorySeparator + 'locale' + DirectorySeparator;

    if FindFirst(LocaleDir + '*', faDirectory, SR) = 0 then
    begin
      repeat
        if ((SR.Attr and faDirectory) = faDirectory) and
           (SR.Name <> '.') and (SR.Name <> '..') then
        begin
          Lang := SR.Name;
          if FileExists(LocaleDir + Lang + DirectorySeparator + 'btt-writer.po') then
            Found.Add(Lang);
        end;
      until FindNext(SR) <> 0;
      FindClose(SR);
    end;

    SetLength(Result, Found.Count);
    for I := 0 to Found.Count - 1 do
      Result[I] := Found[I];
  finally
    Found.Free;
  end;
end;

end.
