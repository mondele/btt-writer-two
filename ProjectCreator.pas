unit ProjectCreator;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, fpjson;

type
  TBookOption = record
    Code: string;
    Name: string;
  end;

  TBookOptionList = array of TBookOption;

  TTargetLanguageOption = record
    Code: string;
    Name: string;
  end;

  TTargetLanguageOptionList = array of TTargetLanguageOption;

  TSourceTextOption = record
    SourceDir: string;
    SourceLangCode: string;
    SourceLangName: string;
    BookCode: string;
    BookName: string;
    ResourceID: string;
    ResourceName: string;
  end;

  TSourceTextOptionList = array of TSourceTextOption;

type
  TProjectTypeID = (ptText, ptNotes, ptQuestions);

function ListSourceTextOptions: TSourceTextOptionList;
function ListBooksFromIndex: TBookOptionList;
function ListTargetLanguagesFromIndex: TTargetLanguageOptionList;
function ListSourceTextOptionsForBookFromIndex(const BookCode: string): TSourceTextOptionList;
function PromptForTargetLanguage(out LangCode, LangName: string): Boolean;
function PromptForBook(out BookCode, BookName: string): Boolean;
function PromptForProjectType(const TargetLangCode, BookCode: string;
  out ProjType: TProjectTypeID): Boolean;
function PromptForSourceText(const BookCode: string; out Opt: TSourceTextOption): Boolean;
function TextProjectExistsFor(const TargetLangCode, BookCode: string): Boolean;
function EnsureSourceTextPresent(const SourceOpt: TSourceTextOption;
  out SourceDir, ErrorMsg: string): Boolean;
function IsCanonicalBibleBookCode(const BookCode: string): Boolean;
function CanonicalBookName(const BookCode: string): string;
function FindSourceTextOption(const SourceLangCode, BookCode, ResourceID: string;
  out Opt: TSourceTextOption): Boolean;
function CreateProjectFromSource(const TargetLangCode, TargetLangName: string;
  const SourceOpt: TSourceTextOption; AProjType: TProjectTypeID;
  out ProjectDir: string; out ErrorMsg: string): Boolean;
function CommitProjectChanges(const ProjectDir, CommitMsg: string;
  out ErrorMsg: string): Boolean;

implementation

uses
  Process, jsonparser, DataPaths, Forms, Controls, StdCtrls, ExtCtrls,
  Dialogs, LCLType, ComCtrls, SourceExtractor, IndexDatabase, AppLog, GitUtils;

const
  NON_GL_RESOURCE_ID = 'reg';
  NON_GL_RESOURCE_NAME = 'Regular';
  PROJECT_TYPE_ID = 'text';
  PROJECT_TYPE_NAME = 'Text';

resourcestring
  rsSourceNotInstalledAndNoBundle =
    'Source text is not installed and bundled resource archive was not found.';
  rsSelectTargetLanguage = 'Select Target Language';
  rsLanguageCode = 'Language code';
  rsLanguageName = 'Language name';
  rsOK = 'OK';
  rsCancel = 'Cancel';
  rsSelectValidLanguageCode = 'Please select a valid language code from the list.';
  rsNoTargetLanguages = 'No target languages found in index.sqlite.';
  rsSelectBook = 'Select Book';
  rsOldTestament = 'Old Testament';
  rsNewTestament = 'New Testament';
  rsPleaseSelectBook = 'Please select a book.';
  rsNoSourceBooks = 'No source books found in index.sqlite.';
  rsSelectSourceText = 'Select Source Text';
  rsPleaseSelectSourceText = 'Please select a source text.';
  rsNoSourceTextsForBookFmt = 'No source texts found for book "%s" in index.sqlite. (Excluded: tn, tq)';
  rsSelectProjectType = 'Select Project Type';
  rsTypeText = 'Text';
  rsTypeNotes = 'Notes (translationNotes)';
  rsTypeQuestions = 'Questions (translationQuestions)';
  rsNotesRequireText = 'A text translation project must exist for %s in %s before creating a Notes or Questions project.';
  rsPleaseSelectProjectType = 'Please select a project type.';

type
  TCanonicalBook = record
    Code: string;
    Name: string;
    IsOT: Boolean;
  end;

const
  CANON_BOOKS: array[0..65] of TCanonicalBook = (
    (Code: 'gen'; Name: 'Genesis'; IsOT: True),
    (Code: 'exo'; Name: 'Exodus'; IsOT: True),
    (Code: 'lev'; Name: 'Leviticus'; IsOT: True),
    (Code: 'num'; Name: 'Numbers'; IsOT: True),
    (Code: 'deu'; Name: 'Deuteronomy'; IsOT: True),
    (Code: 'jos'; Name: 'Joshua'; IsOT: True),
    (Code: 'jdg'; Name: 'Judges'; IsOT: True),
    (Code: 'rut'; Name: 'Ruth'; IsOT: True),
    (Code: '1sa'; Name: '1 Samuel'; IsOT: True),
    (Code: '2sa'; Name: '2 Samuel'; IsOT: True),
    (Code: '1ki'; Name: '1 Kings'; IsOT: True),
    (Code: '2ki'; Name: '2 Kings'; IsOT: True),
    (Code: '1ch'; Name: '1 Chronicles'; IsOT: True),
    (Code: '2ch'; Name: '2 Chronicles'; IsOT: True),
    (Code: 'ezr'; Name: 'Ezra'; IsOT: True),
    (Code: 'neh'; Name: 'Nehemiah'; IsOT: True),
    (Code: 'est'; Name: 'Esther'; IsOT: True),
    (Code: 'job'; Name: 'Job'; IsOT: True),
    (Code: 'psa'; Name: 'Psalms'; IsOT: True),
    (Code: 'pro'; Name: 'Proverbs'; IsOT: True),
    (Code: 'ecc'; Name: 'Ecclesiastes'; IsOT: True),
    (Code: 'sng'; Name: 'Song of Solomon'; IsOT: True),
    (Code: 'isa'; Name: 'Isaiah'; IsOT: True),
    (Code: 'jer'; Name: 'Jeremiah'; IsOT: True),
    (Code: 'lam'; Name: 'Lamentations'; IsOT: True),
    (Code: 'ezk'; Name: 'Ezekiel'; IsOT: True),
    (Code: 'dan'; Name: 'Daniel'; IsOT: True),
    (Code: 'hos'; Name: 'Hosea'; IsOT: True),
    (Code: 'jol'; Name: 'Joel'; IsOT: True),
    (Code: 'amo'; Name: 'Amos'; IsOT: True),
    (Code: 'oba'; Name: 'Obadiah'; IsOT: True),
    (Code: 'jon'; Name: 'Jonah'; IsOT: True),
    (Code: 'mic'; Name: 'Micah'; IsOT: True),
    (Code: 'nam'; Name: 'Nahum'; IsOT: True),
    (Code: 'hab'; Name: 'Habakkuk'; IsOT: True),
    (Code: 'zep'; Name: 'Zephaniah'; IsOT: True),
    (Code: 'hag'; Name: 'Haggai'; IsOT: True),
    (Code: 'zec'; Name: 'Zechariah'; IsOT: True),
    (Code: 'mal'; Name: 'Malachi'; IsOT: True),
    (Code: 'mat'; Name: 'Matthew'; IsOT: False),
    (Code: 'mrk'; Name: 'Mark'; IsOT: False),
    (Code: 'luk'; Name: 'Luke'; IsOT: False),
    (Code: 'jhn'; Name: 'John'; IsOT: False),
    (Code: 'act'; Name: 'Acts'; IsOT: False),
    (Code: 'rom'; Name: 'Romans'; IsOT: False),
    (Code: '1co'; Name: '1 Corinthians'; IsOT: False),
    (Code: '2co'; Name: '2 Corinthians'; IsOT: False),
    (Code: 'gal'; Name: 'Galatians'; IsOT: False),
    (Code: 'eph'; Name: 'Ephesians'; IsOT: False),
    (Code: 'php'; Name: 'Philippians'; IsOT: False),
    (Code: 'col'; Name: 'Colossians'; IsOT: False),
    (Code: '1th'; Name: '1 Thessalonians'; IsOT: False),
    (Code: '2th'; Name: '2 Thessalonians'; IsOT: False),
    (Code: '1ti'; Name: '1 Timothy'; IsOT: False),
    (Code: '2ti'; Name: '2 Timothy'; IsOT: False),
    (Code: 'tit'; Name: 'Titus'; IsOT: False),
    (Code: 'phm'; Name: 'Philemon'; IsOT: False),
    (Code: 'heb'; Name: 'Hebrews'; IsOT: False),
    (Code: 'jas'; Name: 'James'; IsOT: False),
    (Code: '1pe'; Name: '1 Peter'; IsOT: False),
    (Code: '2pe'; Name: '2 Peter'; IsOT: False),
    (Code: '1jn'; Name: '1 John'; IsOT: False),
    (Code: '2jn'; Name: '2 John'; IsOT: False),
    (Code: '3jn'; Name: '3 John'; IsOT: False),
    (Code: 'jud'; Name: 'Jude'; IsOT: False),
    (Code: 'rev'; Name: 'Revelation'; IsOT: False)
  );

type
  TLanguagePickerForm = class(TForm)
  private
    FAll: TTargetLanguageOptionList;
    FVisible: array of Integer;
    FInternalUpdate: Boolean;
    lblCode: TLabel;
    lblName: TLabel;
    edtCode: TEdit;
    edtName: TEdit;
    lst: TListBox;
    btnOK: TButton;
    btnCancel: TButton;
    procedure RebuildVisible;
    procedure edtCodeChange(Sender: TObject);
    procedure edtCodeKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure lstClick(Sender: TObject);
    procedure lstKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure lstDblClick(Sender: TObject);
    procedure btnOKClick(Sender: TObject);
  public
    constructor CreatePicker(AOwner: TComponent; const AAll: TTargetLanguageOptionList);
  end;

  TBookPickerForm = class(TForm)
  private
    FAll: TBookOptionList;
    FOTVisible: array of Integer;
    FNTVisible: array of Integer;
    pages: TPageControl;
    tabOT: TTabSheet;
    tabNT: TTabSheet;
    lstOT: TListBox;
    lstNT: TListBox;
    btnOK: TButton;
    btnCancel: TButton;
    procedure btnOKClick(Sender: TObject);
    procedure lstDblClick(Sender: TObject);
  public
    constructor CreatePicker(AOwner: TComponent; const AAll: TBookOptionList);
    function SelectedBook(out BookCode, BookName: string): Boolean;
  end;

  TSourcePickerForm = class(TForm)
  private
    FAll: TSourceTextOptionList;
    lst: TListBox;
    btnOK: TButton;
    btnCancel: TButton;
    procedure btnOKClick(Sender: TObject);
    procedure lstDblClick(Sender: TObject);
  public
    constructor CreatePicker(AOwner: TComponent; const AAll: TSourceTextOptionList);
    function SelectedOption(out Opt: TSourceTextOption): Boolean;
  end;

function LoadJSONFile(const APath: string): TJSONObject;
var
  SL: TStringList;
  Data: TJSONData;
begin
  Result := nil;
  if not FileExists(APath) then
    Exit;

  SL := TStringList.Create;
  try
    SL.LoadFromFile(APath);
    Data := GetJSON(SL.Text);
    if Data is TJSONObject then
      Result := TJSONObject(Data)
    else
      Data.Free;
  finally
    SL.Free;
  end;
end;

function RunGit(const WorkDir: string; const Args: array of string;
  out ErrorMsg: string): Boolean;
var
  P: TProcess;
  OutS, ErrS: TStringStream;
  I: Integer;
  Buf: array[0..4095] of Byte;
  N: LongInt;
begin
  Result := False;
  ErrorMsg := '';

  P := TProcess.Create(nil);
  OutS := TStringStream.Create('');
  ErrS := TStringStream.Create('');
  try
    P.Executable := 'git';
    P.CurrentDirectory := WorkDir;
    P.Options := [poUsePipes];
    for I := 0 to High(Args) do
      P.Parameters.Add(Args[I]);

    try
      P.Execute;
    except
      on E: Exception do
      begin
        ErrorMsg := E.Message;
        Exit(False);
      end;
    end;

    while P.Running do
    begin
      while P.Output.NumBytesAvailable > 0 do
      begin
        N := P.Output.Read(Buf, SizeOf(Buf));
        if N > 0 then
          OutS.WriteBuffer(Buf, N);
      end;
      while P.Stderr.NumBytesAvailable > 0 do
      begin
        N := P.Stderr.Read(Buf, SizeOf(Buf));
        if N > 0 then
          ErrS.WriteBuffer(Buf, N);
      end;
      Sleep(5);
    end;
    while P.Output.NumBytesAvailable > 0 do
    begin
      N := P.Output.Read(Buf, SizeOf(Buf));
      if N > 0 then
        OutS.WriteBuffer(Buf, N);
    end;
    while P.Stderr.NumBytesAvailable > 0 do
    begin
      N := P.Stderr.Read(Buf, SizeOf(Buf));
      if N > 0 then
        ErrS.WriteBuffer(Buf, N);
    end;

    if P.ExitStatus = 0 then
      Exit(True);

    ErrorMsg := Trim(ErrS.DataString);
    if ErrorMsg = '' then
      ErrorMsg := Trim(OutS.DataString);
    if ErrorMsg = '' then
      ErrorMsg := 'git exited with status ' + IntToStr(P.ExitStatus);
  finally
    ErrS.Free;
    OutS.Free;
    P.Free;
  end;
end;

function ResolveInstalledSourceDir(const SourceOpt: TSourceTextOption): string;
var
  Match: TSourceTextOption;
begin
  Result := '';
  if FindSourceTextOption(SourceOpt.SourceLangCode, SourceOpt.BookCode, SourceOpt.ResourceID, Match) then
    Exit(Match.SourceDir);
  Result := IncludeTrailingPathDelimiter(GetLibraryPath) +
    LowerCase(Trim(SourceOpt.SourceLangCode)) + '_' +
    LowerCase(Trim(SourceOpt.BookCode)) + '_' +
    LowerCase(Trim(SourceOpt.ResourceID));
  if not FileExists(IncludeTrailingPathDelimiter(Result) + 'package.json') then
    Result := '';
end;

function EnsureSourceTextPresent(const SourceOpt: TSourceTextOption;
  out SourceDir, ErrorMsg: string): Boolean;
var
  ZipPath, DestRoot, DestDir, TsrcSlug: string;
begin
  Result := False;
  SourceDir := '';
  ErrorMsg := '';

  SourceDir := ResolveInstalledSourceDir(SourceOpt);
  if SourceDir <> '' then
    Exit(True);

  { Find the bundled zip — uses SourceExtractor's FindBundledZipPath }
  ZipPath := SourceExtractor.FindBundledZipPath;
  if ZipPath = '' then
  begin
    { Fall back to DataPaths install path }
    ZipPath := GetBundledResourceContainersZipPath;
    if (ZipPath = '') or (not FileExists(ZipPath)) then
    begin
      ErrorMsg := rsSourceNotInstalledAndNoBundle;
      Exit(False);
    end;
  end;

  TsrcSlug := LowerCase(Trim(SourceOpt.SourceLangCode)) + '_' +
    LowerCase(Trim(SourceOpt.BookCode)) + '_' +
    LowerCase(Trim(SourceOpt.ResourceID));

  DestRoot := GetLibraryPath;
  DestDir := IncludeTrailingPathDelimiter(DestRoot) + TsrcSlug;

  if not ForceDirectories(DestDir) then
  begin
    ErrorMsg := 'Could not create source container directory: ' + DestDir;
    Exit(False);
  end;

  LogFmt(llInfo, 'Extracting source text: %s → %s', [TsrcSlug, DestDir]);

  if not ExtractTsrc(ZipPath, TsrcSlug, DestDir) then
  begin
    ErrorMsg := 'Failed to extract bundled source text: ' + TsrcSlug + '.tsrc';
    Exit(False);
  end;

  SourceDir := DestDir;
  Result := True;
end;

function CanonicalBookIsOT(const BookCode: string; out IsOT: Boolean): Boolean;
var
  I: Integer;
  Code: string;
begin
  Result := False;
  IsOT := False;
  Code := LowerCase(Trim(BookCode));
  for I := 0 to High(CANON_BOOKS) do
    if Code = CANON_BOOKS[I].Code then
    begin
      IsOT := CANON_BOOKS[I].IsOT;
      Exit(True);
    end;
end;

function IsCanonicalBibleBookCode(const BookCode: string): Boolean;
var
  Dummy: Boolean;
begin
  Result := CanonicalBookIsOT(BookCode, Dummy);
end;

function CanonicalBookName(const BookCode: string): string;
var
  I: Integer;
  Code: string;
begin
  Result := '';
  Code := LowerCase(Trim(BookCode));
  for I := 0 to High(CANON_BOOKS) do
    if CANON_BOOKS[I].Code = Code then
      Exit(CANON_BOOKS[I].Name);
end;

function ListTargetLanguagesFromIndex: TTargetLanguageOptionList;
var
  DB: TIndexDatabase;
  Langs: TTargetLanguageArray;
  I: Integer;
begin
  SetLength(Result, 0);
  DB := OpenIndexDatabase;
  if DB = nil then
    Exit;
  try
    Langs := DB.ListTargetLanguages;
    SetLength(Result, Length(Langs));
    for I := 0 to High(Langs) do
    begin
      Result[I].Code := Langs[I].Slug;
      Result[I].Name := Langs[I].Name;
    end;
  finally
    DB.Free;
  end;
end;

function ListBooksFromIndex: TBookOptionList;
var
  DB: TIndexDatabase;
  SrcLangs: TSourceLanguageArray;
  Books: TBookInfoArray;
  Available: array[0..65] of Boolean;
  I, J, Count: Integer;
  Code: string;
begin
  SetLength(Result, 0);
  DB := OpenIndexDatabase;
  if DB = nil then
    Exit;
  try
    { Get all books across all source languages }
    SrcLangs := DB.ListSourceLanguages;
    for I := 0 to High(Available) do
      Available[I] := False;

    for I := 0 to High(SrcLangs) do
    begin
      Books := DB.ListBooks(SrcLangs[I].Slug, '');
      for J := 0 to High(Books) do
      begin
        Code := LowerCase(Trim(Books[J].Slug));
        for Count := 0 to High(CANON_BOOKS) do
          if Code = CANON_BOOKS[Count].Code then
          begin
            Available[Count] := True;
            Break;
          end;
      end;
    end;

    Count := 0;
    for I := 0 to High(CANON_BOOKS) do
      if Available[I] then
      begin
        Inc(Count);
        SetLength(Result, Count);
        Result[Count - 1].Code := CANON_BOOKS[I].Code;
        Result[Count - 1].Name := CANON_BOOKS[I].Name;
      end;
    if Count = 0 then
    begin
      SetLength(Result, Length(CANON_BOOKS));
      for I := 0 to High(CANON_BOOKS) do
      begin
        Result[I].Code := CANON_BOOKS[I].Code;
        Result[I].Name := CANON_BOOKS[I].Name;
      end;
    end;
  finally
    DB.Free;
  end;
end;

function ListSourceTextOptionsForBookFromIndex(const BookCode: string): TSourceTextOptionList;
var
  DB: TIndexDatabase;
  Resources: TResourceInfoArray;
  I, Count: Integer;
  Opt: TSourceTextOption;
  BookName: string;
begin
  SetLength(Result, 0);
  if Trim(BookCode) = '' then
    Exit;

  DB := OpenIndexDatabase;
  if DB = nil then
    Exit;
  try
    Resources := DB.ListSourceTexts(LowerCase(Trim(BookCode)));
    BookName := CanonicalBookName(BookCode);

    Count := 0;
    for I := 0 to High(Resources) do
    begin
      Opt.SourceLangCode := Resources[I].SourceLangSlug;
      Opt.SourceLangName := Resources[I].SourceLangName;
      Opt.BookCode := LowerCase(Trim(BookCode));
      Opt.BookName := BookName;
      Opt.ResourceID := Resources[I].Slug;
      Opt.ResourceName := Resources[I].Name;
      Opt.SourceDir := '';

      Inc(Count);
      SetLength(Result, Count);
      Result[Count - 1] := Opt;
    end;
  finally
    DB.Free;
  end;
end;

constructor TLanguagePickerForm.CreatePicker(AOwner: TComponent;
  const AAll: TTargetLanguageOptionList);
begin
  inherited Create(AOwner);
  Position := poScreenCenter;
  Width := 560;
  Height := 460;
  BorderIcons := [biSystemMenu];
  Caption := rsSelectTargetLanguage;

  FAll := AAll;
  SetLength(FVisible, 0);

  lblCode := TLabel.Create(Self);
  lblCode.Parent := Self;
  lblCode.Left := 12;
  lblCode.Top := 12;
  lblCode.Caption := rsLanguageCode;

  edtCode := TEdit.Create(Self);
  edtCode.Parent := Self;
  edtCode.Left := 12;
  edtCode.Top := 30;
  edtCode.Width := 220;
  edtCode.OnChange := @edtCodeChange;
  edtCode.OnKeyDown := @edtCodeKeyDown;

  lblName := TLabel.Create(Self);
  lblName.Parent := Self;
  lblName.Left := 250;
  lblName.Top := 12;
  lblName.Caption := rsLanguageName;

  edtName := TEdit.Create(Self);
  edtName.Parent := Self;
  edtName.Left := 250;
  edtName.Top := 30;
  edtName.Width := 290;
  edtName.ReadOnly := True;

  lst := TListBox.Create(Self);
  lst.Parent := Self;
  lst.Left := 12;
  lst.Top := 62;
  lst.Width := 528;
  lst.Height := 330;
  lst.Anchors := [akTop, akLeft, akRight, akBottom];
  lst.OnClick := @lstClick;
  lst.OnKeyUp := @lstKeyUp;
  lst.OnDblClick := @lstDblClick;

  btnOK := TButton.Create(Self);
  btnOK.Parent := Self;
  btnOK.Left := 368;
  btnOK.Top := 402;
  btnOK.Width := 80;
  btnOK.Caption := rsOK;
  btnOK.ModalResult := mrNone;
  btnOK.Default := True;
  btnOK.Anchors := [akRight, akBottom];
  btnOK.OnClick := @btnOKClick;

  btnCancel := TButton.Create(Self);
  btnCancel.Parent := Self;
  btnCancel.Left := 460;
  btnCancel.Top := 402;
  btnCancel.Width := 80;
  btnCancel.Caption := rsCancel;
  btnCancel.ModalResult := mrCancel;
  btnCancel.Anchors := [akRight, akBottom];

  RebuildVisible;
end;

procedure TLanguagePickerForm.RebuildVisible;
var
  I, Count, SelectedVisIdx: Integer;
  Needle: string;
begin
  lst.Items.BeginUpdate;
  try
    lst.Items.Clear;
    SetLength(FVisible, 0);
    Needle := LowerCase(Trim(edtCode.Text));
    Count := 0;
    for I := 0 to Length(FAll) - 1 do
    begin
      if (Needle <> '') and (Pos(Needle, LowerCase(FAll[I].Code)) <> 1) then
        Continue;
      Inc(Count);
      SetLength(FVisible, Count);
      FVisible[Count - 1] := I;
      lst.Items.Add(FAll[I].Code + '  -  ' + FAll[I].Name);
    end;
  finally
    lst.Items.EndUpdate;
  end;

  SelectedVisIdx := -1;
  for I := 0 to Length(FVisible) - 1 do
    if SameText(FAll[FVisible[I]].Code, Trim(edtCode.Text)) then
    begin
      SelectedVisIdx := I;
      Break;
    end;

  if lst.Items.Count > 0 then
  begin
    if SelectedVisIdx >= 0 then
      lst.ItemIndex := SelectedVisIdx
    else
      lst.ItemIndex := 0;
    FInternalUpdate := True;
    try
      edtName.Text := FAll[FVisible[lst.ItemIndex]].Name;
    finally
      FInternalUpdate := False;
    end;
  end
  else
  begin
    FInternalUpdate := True;
    try
      edtName.Text := '';
    finally
      FInternalUpdate := False;
    end;
  end;
end;

procedure TLanguagePickerForm.edtCodeChange(Sender: TObject);
begin
  if FInternalUpdate then
    Exit;
  RebuildVisible;
end;

procedure TLanguagePickerForm.edtCodeKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if Key = VK_TAB then
  begin
    if lst.Items.Count > 0 then
    begin
      lst.SetFocus;
      if lst.ItemIndex < 0 then
        lst.ItemIndex := 0;
      lstClick(lst);
      Key := 0;
    end;
  end;
end;

procedure TLanguagePickerForm.lstClick(Sender: TObject);
var
  Idx: Integer;
begin
  Idx := lst.ItemIndex;
  if (Idx < 0) or (Idx >= Length(FVisible)) then
    Exit;
  FInternalUpdate := True;
  try
    edtCode.Text := FAll[FVisible[Idx]].Code;
    edtName.Text := FAll[FVisible[Idx]].Name;
  finally
    FInternalUpdate := False;
  end;
end;

procedure TLanguagePickerForm.lstKeyUp(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  case Key of
    VK_UP, VK_DOWN, VK_PRIOR, VK_NEXT, VK_HOME, VK_END:
      lstClick(Sender);
  end;
end;

procedure TLanguagePickerForm.lstDblClick(Sender: TObject);
begin
  btnOKClick(Sender);
end;

procedure TLanguagePickerForm.btnOKClick(Sender: TObject);
var
  I, Idx: Integer;
  Code: string;
begin
  Idx := lst.ItemIndex;
  if (Idx >= 0) and (Idx < Length(FVisible)) then
  begin
    edtCode.Text := FAll[FVisible[Idx]].Code;
    edtName.Text := FAll[FVisible[Idx]].Name;
    ModalResult := mrOK;
    Exit;
  end;

  Code := Trim(edtCode.Text);
  for I := 0 to Length(FAll) - 1 do
    if SameText(FAll[I].Code, Code) then
    begin
      edtCode.Text := FAll[I].Code;
      edtName.Text := FAll[I].Name;
      ModalResult := mrOK;
      Exit;
    end;
  MessageDlg(rsSelectValidLanguageCode, mtWarning, [mbOK], 0);
end;

function PromptForTargetLanguage(out LangCode, LangName: string): Boolean;
var
  L: TTargetLanguageOptionList;
  F: TLanguagePickerForm;
begin
  Result := False;
  LangCode := '';
  LangName := '';

  L := ListTargetLanguagesFromIndex;
  if Length(L) = 0 then
  begin
    MessageDlg(rsNoTargetLanguages, mtError, [mbOK], 0);
    Exit;
  end;

  F := TLanguagePickerForm.CreatePicker(nil, L);
  try
    if F.ShowModal <> mrOK then
      Exit;
    LangCode := Trim(F.edtCode.Text);
    LangName := Trim(F.edtName.Text);
    Result := (LangCode <> '') and (LangName <> '');
  finally
    F.Free;
  end;
end;

constructor TBookPickerForm.CreatePicker(AOwner: TComponent;
  const AAll: TBookOptionList);
var
  I, Count: Integer;
  IsOT: Boolean;
begin
  inherited Create(AOwner);
  Position := poScreenCenter;
  Width := 620;
  Height := 480;
  BorderIcons := [biSystemMenu];
  Caption := rsSelectBook;

  FAll := AAll;
  SetLength(FOTVisible, 0);
  SetLength(FNTVisible, 0);

  pages := TPageControl.Create(Self);
  pages.Parent := Self;
  pages.Left := 12;
  pages.Top := 12;
  pages.Width := 596;
  pages.Height := 400;
  pages.Anchors := [akTop, akLeft, akRight, akBottom];

  tabOT := TTabSheet.Create(pages);
  tabOT.PageControl := pages;
  tabOT.Caption := rsOldTestament;

  tabNT := TTabSheet.Create(pages);
  tabNT.PageControl := pages;
  tabNT.Caption := rsNewTestament;

  lstOT := TListBox.Create(Self);
  lstOT.Parent := tabOT;
  lstOT.Align := alClient;
  lstOT.OnDblClick := @lstDblClick;

  lstNT := TListBox.Create(Self);
  lstNT.Parent := tabNT;
  lstNT.Align := alClient;
  lstNT.OnDblClick := @lstDblClick;

  for I := 0 to Length(FAll) - 1 do
    if CanonicalBookIsOT(FAll[I].Code, IsOT) and IsOT then
    begin
      Count := Length(FOTVisible);
      SetLength(FOTVisible, Count + 1);
      FOTVisible[Count] := I;
      lstOT.Items.Add(FAll[I].Code + '  -  ' + FAll[I].Name);
    end
    else
    begin
      Count := Length(FNTVisible);
      SetLength(FNTVisible, Count + 1);
      FNTVisible[Count] := I;
      lstNT.Items.Add(FAll[I].Code + '  -  ' + FAll[I].Name);
    end;
  if lstOT.Items.Count > 0 then
    lstOT.ItemIndex := 0;
  if lstNT.Items.Count > 0 then
    lstNT.ItemIndex := 0;
  pages.ActivePage := tabOT;

  btnOK := TButton.Create(Self);
  btnOK.Parent := Self;
  btnOK.Left := 436;
  btnOK.Top := 420;
  btnOK.Width := 80;
  btnOK.Caption := rsOK;
  btnOK.ModalResult := mrNone;
  btnOK.Anchors := [akRight, akBottom];
  btnOK.OnClick := @btnOKClick;

  btnCancel := TButton.Create(Self);
  btnCancel.Parent := Self;
  btnCancel.Left := 528;
  btnCancel.Top := 420;
  btnCancel.Width := 80;
  btnCancel.Caption := rsCancel;
  btnCancel.ModalResult := mrCancel;
  btnCancel.Anchors := [akRight, akBottom];
end;

procedure TBookPickerForm.btnOKClick(Sender: TObject);
begin
  if (pages.ActivePage = tabOT) and
     ((lstOT.ItemIndex < 0) or (lstOT.ItemIndex >= Length(FOTVisible))) then
  begin
    MessageDlg(rsPleaseSelectBook, mtWarning, [mbOK], 0);
    Exit;
  end;
  if (pages.ActivePage = tabNT) and
     ((lstNT.ItemIndex < 0) or (lstNT.ItemIndex >= Length(FNTVisible))) then
  begin
    MessageDlg(rsPleaseSelectBook, mtWarning, [mbOK], 0);
    Exit;
  end;
  ModalResult := mrOK;
end;

procedure TBookPickerForm.lstDblClick(Sender: TObject);
begin
  btnOKClick(Sender);
end;

function TBookPickerForm.SelectedBook(out BookCode, BookName: string): Boolean;
var
  Idx: Integer;
begin
  Result := False;
  BookCode := '';
  BookName := '';
  if pages.ActivePage = tabOT then
  begin
    Idx := lstOT.ItemIndex;
    if (Idx < 0) or (Idx >= Length(FOTVisible)) then
      Exit;
    BookCode := FAll[FOTVisible[Idx]].Code;
    BookName := FAll[FOTVisible[Idx]].Name;
    Exit(True);
  end;
  Idx := lstNT.ItemIndex;
  if (Idx < 0) or (Idx >= Length(FNTVisible)) then
    Exit;
  BookCode := FAll[FNTVisible[Idx]].Code;
  BookName := FAll[FNTVisible[Idx]].Name;
  Result := True;
end;

function PromptForBook(out BookCode, BookName: string): Boolean;
var
  L: TBookOptionList;
  F: TBookPickerForm;
begin
  Result := False;
  BookCode := '';
  BookName := '';

  L := ListBooksFromIndex;
  if Length(L) = 0 then
  begin
    MessageDlg(rsNoSourceBooks, mtError, [mbOK], 0);
    Exit;
  end;

  F := TBookPickerForm.CreatePicker(nil, L);
  try
    if F.ShowModal <> mrOK then
      Exit;
    Result := F.SelectedBook(BookCode, BookName);
  finally
    F.Free;
  end;
end;

function TextProjectExistsFor(const TargetLangCode, BookCode: string): Boolean;
var
  BasePath, DirPath, DirName: string;
  SR: TSearchRec;
  Parts: TStringArray;
begin
  Result := False;
  BasePath := GetTargetTranslationsPath;
  if not DirectoryExists(BasePath) then
    Exit;

  { Look for {langCode}_{bookCode}_text_* directories }
  if FindFirst(BasePath + '*', faDirectory, SR) <> 0 then
    Exit;
  try
    repeat
      if (SR.Name = '.') or (SR.Name = '..') then
        Continue;
      if (SR.Attr and faDirectory) = 0 then
        Continue;
      DirName := SR.Name;
      Parts := string(DirName).Split('_');
      { Format: langCode_bookCode_text_resourceType }
      if Length(Parts) >= 3 then
        if (CompareText(Parts[0], TargetLangCode) = 0) and
           (CompareText(Parts[1], BookCode) = 0) and
           (CompareText(Parts[2], 'text') = 0) then
        begin
          { Verify manifest exists }
          DirPath := IncludeTrailingPathDelimiter(BasePath + DirName);
          if FileExists(DirPath + 'manifest.json') then
            Exit(True);
        end;
    until FindNext(SR) <> 0;
  finally
    FindClose(SR);
  end;
end;

function PromptForProjectType(const TargetLangCode, BookCode: string;
  out ProjType: TProjectTypeID): Boolean;
var
  F: TForm;
  Lst: TListBox;
  BtnOK, BtnCancel: TButton;
  HasText: Boolean;
  BookName: string;
begin
  Result := False;
  ProjType := ptText;

  HasText := TextProjectExistsFor(TargetLangCode, BookCode);
  BookName := CanonicalBookName(BookCode);
  if BookName = '' then
    BookName := BookCode;

  F := TForm.Create(nil);
  try
    F.Position := poScreenCenter;
    F.Width := 420;
    F.Height := 280;
    F.BorderIcons := [biSystemMenu];
    F.Caption := rsSelectProjectType;

    Lst := TListBox.Create(F);
    Lst.Parent := F;
    Lst.Left := 12;
    Lst.Top := 12;
    Lst.Width := 396;
    Lst.Height := 190;
    Lst.Anchors := [akTop, akLeft, akRight, akBottom];

    Lst.Items.Add(rsTypeText);
    Lst.Items.Add(rsTypeNotes);
    Lst.Items.Add(rsTypeQuestions);
    Lst.ItemIndex := 0;

    BtnOK := TButton.Create(F);
    BtnOK.Parent := F;
    BtnOK.Left := 236;
    BtnOK.Top := 214;
    BtnOK.Width := 80;
    BtnOK.Caption := rsOK;
    BtnOK.Default := True;
    BtnOK.ModalResult := mrOK;
    BtnOK.Anchors := [akRight, akBottom];

    BtnCancel := TButton.Create(F);
    BtnCancel.Parent := F;
    BtnCancel.Left := 328;
    BtnCancel.Top := 214;
    BtnCancel.Width := 80;
    BtnCancel.Caption := rsCancel;
    BtnCancel.ModalResult := mrCancel;
    BtnCancel.Anchors := [akRight, akBottom];

    if F.ShowModal <> mrOK then
      Exit;

    case Lst.ItemIndex of
      0: ProjType := ptText;
      1: begin
        if not HasText then
        begin
          MessageDlg(Format(rsNotesRequireText, [BookName, TargetLangCode]),
            mtWarning, [mbOK], 0);
          Exit;
        end;
        ProjType := ptNotes;
      end;
      2: begin
        if not HasText then
        begin
          MessageDlg(Format(rsNotesRequireText, [BookName, TargetLangCode]),
            mtWarning, [mbOK], 0);
          Exit;
        end;
        ProjType := ptQuestions;
      end;
    else
      begin
        MessageDlg(rsPleaseSelectProjectType, mtWarning, [mbOK], 0);
        Exit;
      end;
    end;
    Result := True;
  finally
    F.Free;
  end;
end;

constructor TSourcePickerForm.CreatePicker(AOwner: TComponent;
  const AAll: TSourceTextOptionList);
var
  I, PrefIdx: Integer;
begin
  inherited Create(AOwner);
  Position := poScreenCenter;
  Width := 760;
  Height := 480;
  BorderIcons := [biSystemMenu];
  Caption := rsSelectSourceText;

  FAll := AAll;

  lst := TListBox.Create(Self);
  lst.Parent := Self;
  lst.Left := 12;
  lst.Top := 12;
  lst.Width := 736;
  lst.Height := 400;
  lst.Anchors := [akTop, akLeft, akRight, akBottom];
  lst.OnDblClick := @lstDblClick;

  PrefIdx := -1;
  for I := 0 to Length(FAll) - 1 do
  begin
    lst.Items.Add(
      FAll[I].SourceLangCode + '  -  ' + FAll[I].SourceLangName +
      '    |    ' + FAll[I].ResourceID + '  -  ' + FAll[I].ResourceName
    );
    if (PrefIdx < 0) and (CompareText(FAll[I].SourceLangCode, 'en') = 0) and
       (CompareText(FAll[I].ResourceID, 'ulb') = 0) then
      PrefIdx := I;
  end;
  if lst.Items.Count > 0 then
    if PrefIdx >= 0 then
      lst.ItemIndex := PrefIdx
    else
      lst.ItemIndex := 0;

  btnOK := TButton.Create(Self);
  btnOK.Parent := Self;
  btnOK.Left := 576;
  btnOK.Top := 420;
  btnOK.Width := 80;
  btnOK.Caption := rsOK;
  btnOK.ModalResult := mrNone;
  btnOK.Anchors := [akRight, akBottom];
  btnOK.OnClick := @btnOKClick;

  btnCancel := TButton.Create(Self);
  btnCancel.Parent := Self;
  btnCancel.Left := 668;
  btnCancel.Top := 420;
  btnCancel.Width := 80;
  btnCancel.Caption := rsCancel;
  btnCancel.ModalResult := mrCancel;
  btnCancel.Anchors := [akRight, akBottom];
end;

procedure TSourcePickerForm.btnOKClick(Sender: TObject);
begin
  if (lst.ItemIndex < 0) or (lst.ItemIndex >= Length(FAll)) then
  begin
    MessageDlg(rsPleaseSelectSourceText, mtWarning, [mbOK], 0);
    Exit;
  end;
  ModalResult := mrOK;
end;

procedure TSourcePickerForm.lstDblClick(Sender: TObject);
begin
  btnOKClick(Sender);
end;

function TSourcePickerForm.SelectedOption(out Opt: TSourceTextOption): Boolean;
begin
  Result := False;
  if (lst.ItemIndex < 0) or (lst.ItemIndex >= Length(FAll)) then
    Exit;
  Opt := FAll[lst.ItemIndex];
  Result := True;
end;

function PromptForSourceText(const BookCode: string; out Opt: TSourceTextOption): Boolean;
var
  L: TSourceTextOptionList;
  F: TSourcePickerForm;
begin
  Result := False;
  Opt.SourceDir := '';
  Opt.SourceLangCode := '';
  Opt.SourceLangName := '';
  Opt.BookCode := '';
  Opt.BookName := '';
  Opt.ResourceID := '';
  Opt.ResourceName := '';

  L := ListSourceTextOptionsForBookFromIndex(BookCode);
  if Length(L) = 0 then
  begin
    MessageDlg(Format(rsNoSourceTextsForBookFmt, [Trim(BookCode)]), mtError, [mbOK], 0);
    Exit;
  end;

  F := TSourcePickerForm.CreatePicker(nil, L);
  try
    if F.ShowModal <> mrOK then
      Exit;
    Result := F.SelectedOption(Opt);
  finally
    F.Free;
  end;
end;

function ListSourceTextOptions: TSourceTextOptionList;
var
  BasePath: string;
  SR: TSearchRec;
  Count: Integer;
  DirPath, PackagePath, ResourceSlug, ResourceType: string;
  Obj, LangObj, ProjObj, ResObj: TJSONObject;
  Opt: TSourceTextOption;
begin
  SetLength(Result, 0);
  Count := 0;
  BasePath := GetLibraryPath;

  if not DirectoryExists(BasePath) then
    Exit;

  if FindFirst(IncludeTrailingPathDelimiter(BasePath) + '*', faDirectory, SR) <> 0 then
    Exit;
  try
    repeat
      if (SR.Name = '.') or (SR.Name = '..') then
        Continue;
      if (SR.Attr and faDirectory) = 0 then
        Continue;

      DirPath := IncludeTrailingPathDelimiter(BasePath) + SR.Name;
      PackagePath := IncludeTrailingPathDelimiter(DirPath) + 'package.json';
      if not FileExists(PackagePath) then
        Continue;

      Obj := LoadJSONFile(PackagePath);
      if Obj = nil then
        Continue;
      try
        if not (Obj.Find('language') is TJSONObject) then
          Continue;
        if not (Obj.Find('project') is TJSONObject) then
          Continue;
        if not (Obj.Find('resource') is TJSONObject) then
          Continue;

        LangObj := TJSONObject(Obj.Find('language'));
        ProjObj := TJSONObject(Obj.Find('project'));
        ResObj := TJSONObject(Obj.Find('resource'));

        ResourceSlug := LowerCase(Trim(ResObj.Get('slug', '')));
        ResourceType := LowerCase(Trim(ResObj.Get('type', '')));

        if ResourceSlug = '' then
          Continue;
        if (ResourceSlug = 'tn') or (ResourceSlug = 'tq') then
          Continue;
        if (ResourceType <> '') and (ResourceType <> 'book') then
          Continue;

        Opt.SourceDir := DirPath;
        Opt.SourceLangCode := LangObj.Get('slug', '');
        Opt.SourceLangName := LangObj.Get('name', '');
        Opt.BookCode := ProjObj.Get('slug', '');
        Opt.BookName := ProjObj.Get('name', '');
        Opt.ResourceID := ResObj.Get('slug', '');
        Opt.ResourceName := ResObj.Get('name', '');

        if (Opt.SourceLangCode = '') or (Opt.BookCode = '') then
          Continue;

        Inc(Count);
        SetLength(Result, Count);
        Result[Count - 1] := Opt;
      finally
        Obj.Free;
      end;
    until FindNext(SR) <> 0;
  finally
    FindClose(SR);
  end;
end;

function CopyFileSimple(const SrcPath, DstPath: string): Boolean;
var
  Src, Dst: TFileStream;
begin
  Result := False;
  if not FileExists(SrcPath) then
    Exit;
  Src := TFileStream.Create(SrcPath, fmOpenRead or fmShareDenyNone);
  try
    Dst := TFileStream.Create(DstPath, fmCreate);
    try
      Dst.CopyFrom(Src, 0);
      Result := True;
    finally
      Dst.Free;
    end;
  finally
    Src.Free;
  end;
end;

function FindSourceTextOption(const SourceLangCode, BookCode, ResourceID: string;
  out Opt: TSourceTextOption): Boolean;
var
  L: TSourceTextOptionList;
  I: Integer;
begin
  Result := False;
  L := ListSourceTextOptions;
  for I := 0 to Length(L) - 1 do
    if (CompareText(L[I].SourceLangCode, SourceLangCode) = 0) and
       (CompareText(L[I].BookCode, BookCode) = 0) and
       (CompareText(L[I].ResourceID, ResourceID) = 0) then
    begin
      Opt := L[I];
      Exit(True);
    end;
end;

function FindLicenseFile(const SourceDir: string): string;
begin
  Result := IncludeTrailingPathDelimiter(SourceDir) + 'LICENSE.md';
  if not FileExists(Result) then
    Result := '';
end;

function ProjectTypeToManifest(AProjType: TProjectTypeID;
  out TypeID, TypeName, ResourceID, ResourceName, Format: string): Boolean;
begin
  Result := True;
  case AProjType of
    ptNotes: begin
      TypeID := 'tn';
      TypeName := 'Notes';
      ResourceID := 'tn';
      ResourceName := 'translationNotes';
      Format := 'json';
    end;
    ptQuestions: begin
      TypeID := 'tq';
      TypeName := 'Questions';
      ResourceID := 'tq';
      ResourceName := 'translationQuestions';
      Format := 'json';
    end;
  else
    begin
      TypeID := PROJECT_TYPE_ID;
      TypeName := PROJECT_TYPE_NAME;
      ResourceID := NON_GL_RESOURCE_ID;
      ResourceName := NON_GL_RESOURCE_NAME;
      Format := 'usfm';
    end;
  end;
end;

function BuildManifestJSON(const TargetLangCode, TargetLangName: string;
  const SourceOpt: TSourceTextOption; AProjType: TProjectTypeID): TJSONObject;
var
  TargetObj, ProjectObj, TypeObj, ResourceObj, GeneratorObj, SourceObj: TJSONObject;
  SourcesArr, TranslatorsArr, FinishedArr: TJSONArray;
  ProjectName: string;
  MTypeID, MTypeName, MResID, MResName, MFormat: string;
begin
  ProjectTypeToManifest(AProjType, MTypeID, MTypeName, MResID, MResName, MFormat);

  Result := TJSONObject.Create;
  Result.Add('package_version', 8);
  Result.Add('format', MFormat);

  GeneratorObj := TJSONObject.Create;
  GeneratorObj.Add('name', 'btt-writer-two');
  GeneratorObj.Add('build', 'codex');
  Result.Add('generator', GeneratorObj);

  TargetObj := TJSONObject.Create;
  TargetObj.Add('name', TargetLangName);
  TargetObj.Add('direction', 'ltr');
  TargetObj.Add('anglicized_name', TargetLangName);
  TargetObj.Add('region', '');
  TargetObj.Add('is_gateway_language', False);
  TargetObj.Add('id', TargetLangCode);
  Result.Add('target_language', TargetObj);

  ProjectObj := TJSONObject.Create;
  ProjectName := CanonicalBookName(SourceOpt.BookCode);
  if ProjectName = '' then
    ProjectName := Trim(SourceOpt.BookName);
  if ProjectName = '' then
    ProjectName := SourceOpt.BookCode;
  ProjectObj.Add('id', SourceOpt.BookCode);
  ProjectObj.Add('name', ProjectName);
  Result.Add('project', ProjectObj);

  TypeObj := TJSONObject.Create;
  TypeObj.Add('id', MTypeID);
  TypeObj.Add('name', MTypeName);
  Result.Add('type', TypeObj);

  ResourceObj := TJSONObject.Create;
  ResourceObj.Add('id', MResID);
  ResourceObj.Add('name', MResName);
  Result.Add('resource', ResourceObj);

  SourcesArr := TJSONArray.Create;
  SourceObj := TJSONObject.Create;
  SourceObj.Add('language_id', SourceOpt.SourceLangCode);
  SourceObj.Add('resource_id', SourceOpt.ResourceID);
  SourceObj.Add('checking_level', '3');
  SourceObj.Add('date_modified', FormatDateTime('yyyy"-"mm"-"dd"T"hh":"nn":"ss', Now));
  SourceObj.Add('version', '1');
  SourcesArr.Add(SourceObj);
  Result.Add('source_translations', SourcesArr);

  TranslatorsArr := TJSONArray.Create;
  TranslatorsArr.Add('Raphael');
  Result.Add('translators', TranslatorsArr);

  FinishedArr := TJSONArray.Create;
  Result.Add('finished_chunks', FinishedArr);
end;

function CreateProjectFromSource(const TargetLangCode, TargetLangName: string;
  const SourceOpt: TSourceTextOption; AProjType: TProjectTypeID;
  out ProjectDir: string; out ErrorMsg: string): Boolean;
var
  DirName, FullDir, ManifestPath, LicenseSrc, LicenseDst, SourceDir: string;
  MTypeID, MTypeName, MResID, MResName, MFormat: string;
  Manifest: TJSONObject;
  SL: TStringList;
  GitErr: string;
begin
  Result := False;
  ErrorMsg := '';
  ProjectDir := '';

  if not EnsureSourceTextPresent(SourceOpt, SourceDir, ErrorMsg) then
    Exit(False);

  ProjectTypeToManifest(AProjType, MTypeID, MTypeName, MResID, MResName, MFormat);
  DirName := TargetLangCode + '_' + SourceOpt.BookCode + '_' +
    MTypeID + '_' + MResID;
  FullDir := IncludeTrailingPathDelimiter(GetTargetTranslationsPath) + DirName;
  if DirectoryExists(FullDir) then
  begin
    ErrorMsg := 'Project already exists: ' + FullDir;
    Exit;
  end;

  if not ForceDirectories(FullDir) then
  begin
    ErrorMsg := 'Could not create project directory: ' + FullDir;
    Exit;
  end;

  Manifest := BuildManifestJSON(TargetLangCode, TargetLangName, SourceOpt, AProjType);
  try
    ManifestPath := IncludeTrailingPathDelimiter(FullDir) + 'manifest.json';
    SL := TStringList.Create;
    try
      SL.Text := Manifest.FormatJSON;
      SL.SaveToFile(ManifestPath);
    finally
      SL.Free;
    end;
  finally
    Manifest.Free;
  end;

  LicenseSrc := FindLicenseFile(SourceDir);
  if LicenseSrc <> '' then
  begin
    LicenseDst := IncludeTrailingPathDelimiter(FullDir) + 'LICENSE.md';
    CopyFileSimple(LicenseSrc, LicenseDst);
  end;

  if not RunGit(FullDir, ['init'], GitErr) then
  begin
    ErrorMsg := 'Project created but git init failed: ' + GitErr;
    ProjectDir := FullDir;
    Exit(False);
  end;
  RunGit(FullDir, ['config', 'user.name', 'BTT Writer Two'], GitErr);
  RunGit(FullDir, ['config', 'user.email', 'bttwriter2@local'], GitErr);
  if not RunGit(FullDir, ['add', 'manifest.json', 'LICENSE.md'], GitErr) then
    if not RunGit(FullDir, ['add', 'manifest.json'], GitErr) then
    begin
      ErrorMsg := 'Project created but git add failed: ' + GitErr;
      ProjectDir := FullDir;
      Exit(False);
    end;

  if not RunGit(FullDir, ['commit', '-m', 'Initial project scaffold'], GitErr) then
  begin
    ErrorMsg := 'Project created but git commit failed: ' + GitErr;
    ProjectDir := FullDir;
    Exit(False);
  end;

  ProjectDir := FullDir;
  Result := True;
end;

function CommitProjectChanges(const ProjectDir, CommitMsg: string;
  out ErrorMsg: string): Boolean;
var
  OutText, ErrText: string;
  ExitCode: Integer;
begin
  Result := False;
  ErrorMsg := '';

  if not DirectoryExists(ProjectDir) then
  begin
    ErrorMsg := 'Project directory not found: ' + ProjectDir;
    Exit;
  end;

  if not RunCommandCapture('git', ['status', '--porcelain'], ProjectDir, OutText, ErrText, ExitCode) then
  begin
    ErrorMsg := ErrText;
    Exit;
  end;
  if ExitCode <> 0 then
  begin
    ErrorMsg := Trim(ErrText);
    Exit;
  end;
  if Trim(OutText) = '' then
    Exit(True); { nothing to commit }

  if not RunGit(ProjectDir, ['add', '-A'], ErrorMsg) then
    Exit(False);

  if not RunGit(ProjectDir, ['commit', '-m', CommitMsg], ErrorMsg) then
  begin
    { treat "nothing to commit" as success in race-y paths }
    if Pos('nothing to commit', LowerCase(ErrorMsg)) > 0 then
      Exit(True);
    Exit(False);
  end;

  Result := True;
end;

end.
