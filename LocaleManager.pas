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

uses
  Classes, StdCtrls;

type
  TLangArray = array of string;

function ApplyInterfaceLanguage: string;
procedure HotReloadInterfaceLanguage;
function ListAvailableLanguages: TLangArray;
procedure PopulateLanguageCombo(Combo: TComboBox);

implementation

uses
  SysUtils, Forms, LResources, Translations, LCLTranslator,
  AppSettings, DataPaths, AppLog;

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

    { Also install LRSTranslator so .lfm-baked captions (Caption=, Text=,
      Hint=, Title= properties stored in form streams) get translated at
      form-construction time. Replace any previous translator. }
    if Assigned(LRSTranslator) then
      LRSTranslator.Free;
    LRSTranslator := TPOTranslator.Create(POPath);

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

procedure HotReloadInterfaceLanguage;
var
  POPath: string;
  I: Integer;
  F: TCustomForm;
begin
  POPath := ApplyInterfaceLanguage;
  if (POPath = '') and (GetInterfaceLanguage <> 'en') then
  begin
    LogWarn('HotReloadInterfaceLanguage: no .po loaded, skipping form walk');
    Exit;
  end;

  { Walk every visible form and re-apply the new translator. LFM-backed
    properties (Caption, Text, Hint) are looked up by component identifier
    path and update cleanly in both directions. Code-assigned Captions
    set from resourcestrings stay at their assigned-time value until the
    form is recreated — accepted limitation. }
  if (LRSTranslator <> nil) and (LRSTranslator is TUpdateTranslator) then
  begin
    for I := 0 to Screen.FormCount - 1 do
    begin
      F := Screen.Forms[I];
      try
        TUpdateTranslator(LRSTranslator).UpdateTranslation(F);
      except
        on E: Exception do
          LogWarn('HotReload: form ' + F.ClassName + ' — ' + E.Message);
      end;
    end;
    LogInfo('HotReload: walked ' + IntToStr(Screen.FormCount) + ' forms');
  end;
end;

procedure PopulateLanguageCombo(Combo: TComboBox);
var
  Langs: TLangArray;
  Lang, Current: string;
  I, Selected: Integer;
begin
  if Combo = nil then Exit;
  Langs := ListAvailableLanguages;
  Current := GetInterfaceLanguage;
  if Current = '' then Current := 'en';

  Combo.Items.BeginUpdate;
  try
    Combo.Items.Clear;
    Selected := -1;
    for I := 0 to High(Langs) do
    begin
      Lang := Langs[I];
      Combo.Items.Add(Lang);
      if Lang = Current then
        Selected := I;
    end;
    if Selected < 0 then
    begin
      { Current language has no .po on disk — show it anyway so the user can
        see what is configured. }
      Combo.Items.Add(Current);
      Selected := Combo.Items.Count - 1;
    end;
    Combo.ItemIndex := Selected;
  finally
    Combo.Items.EndUpdate;
  end;
end;

end.
