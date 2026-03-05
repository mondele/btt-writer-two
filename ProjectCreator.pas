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

function ListSourceTextOptions: TSourceTextOptionList;
function ListBooksFromIndex: TBookOptionList;
function ListTargetLanguagesFromIndex: TTargetLanguageOptionList;
function ListSourceTextOptionsForBookFromIndex(const BookCode: string): TSourceTextOptionList;
function PromptForTargetLanguage(out LangCode, LangName: string): Boolean;
function PromptForBook(out BookCode, BookName: string): Boolean;
function PromptForSourceText(const BookCode: string; out Opt: TSourceTextOption): Boolean;
function FindSourceTextOption(const SourceLangCode, BookCode, ResourceID: string;
  out Opt: TSourceTextOption): Boolean;
function CreateProjectFromSource(const TargetLangCode, TargetLangName: string;
  const SourceOpt: TSourceTextOption; out ProjectDir: string;
  out ErrorMsg: string): Boolean;
function CommitProjectChanges(const ProjectDir, CommitMsg: string;
  out ErrorMsg: string): Boolean;

implementation

uses
  Process, jsonparser, DataPaths, Forms, Controls, StdCtrls, ExtCtrls,
  Dialogs, LCLType;

const
  NON_GL_RESOURCE_ID = 'reg';
  NON_GL_RESOURCE_NAME = 'Regular';
  PROJECT_TYPE_ID = 'text';
  PROJECT_TYPE_NAME = 'Text';

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
    lst: TListBox;
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

function RunCommandCapture(const Exe: string; const Args: array of string;
  const WorkDir: string; out OutputText, ErrorText: string; out ExitCode: Integer): Boolean;
var
  P: TProcess;
  OutS, ErrS: TStringStream;
  I: Integer;
  Buf: array[0..4095] of Byte;
  N: LongInt;
begin
  Result := False;
  OutputText := '';
  ErrorText := '';
  ExitCode := -1;

  P := TProcess.Create(nil);
  OutS := TStringStream.Create('');
  ErrS := TStringStream.Create('');
  try
    P.Executable := Exe;
    if WorkDir <> '' then
      P.CurrentDirectory := WorkDir;
    P.Options := [poUsePipes];
    for I := 0 to High(Args) do
      P.Parameters.Add(Args[I]);
    try
      P.Execute;
    except
      on E: Exception do
      begin
        ErrorText := E.Message;
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
    OutputText := OutS.DataString;
    ErrorText := ErrS.DataString;
    ExitCode := P.ExitStatus;
    Result := True;
  finally
    ErrS.Free;
    OutS.Free;
    P.Free;
  end;
end;

function GetIndexSQLitePath: string;
begin
  Result := IncludeTrailingPathDelimiter(GetDataPath) + 'library' + DirectorySeparator + 'index.sqlite';
end;

function ListTargetLanguagesFromIndex: TTargetLanguageOptionList;
var
  OutText, ErrText, Line: string;
  ExitCode, Count, P: Integer;
  Lines: TStringList;
  Opt: TTargetLanguageOption;
begin
  SetLength(Result, 0);
  if not FileExists(GetIndexSQLitePath) then
    Exit;

  if not RunCommandCapture('sqlite3',
    [GetIndexSQLitePath, 'SELECT slug || char(9) || name FROM target_language ORDER BY slug;'],
    '', OutText, ErrText, ExitCode) then
    Exit;
  if ExitCode <> 0 then
    Exit;

  Lines := TStringList.Create;
  try
    Lines.Text := StringReplace(OutText, #13, '', [rfReplaceAll]);
    Count := 0;
    for P := 0 to Lines.Count - 1 do
    begin
      Line := Trim(Lines[P]);
      if Line = '' then
        Continue;
      Opt.Code := Copy(Line, 1, Pos(#9, Line) - 1);
      Opt.Name := Copy(Line, Pos(#9, Line) + 1, MaxInt);
      if (Opt.Code = '') or (Opt.Name = '') then
        Continue;
      Inc(Count);
      SetLength(Result, Count);
      Result[Count - 1] := Opt;
    end;
  finally
    Lines.Free;
  end;
end;

function ListBooksFromIndex: TBookOptionList;
var
  OutText, ErrText, Line: string;
  ExitCode, Count, P, TabPos: Integer;
  Lines: TStringList;
  Opt: TBookOption;
begin
  SetLength(Result, 0);
  if not FileExists(GetIndexSQLitePath) then
    Exit;

  if not RunCommandCapture('sqlite3',
    [GetIndexSQLitePath,
     'SELECT p.slug || char(9) || p.name ' +
     'FROM project p ' +
     'JOIN resource r ON r.project_id = p.id ' +
     'WHERE r.type = ''book'' ' +
     'AND lower(r.slug) NOT IN (''tn'', ''tq'') ' +
     'GROUP BY p.slug, p.name ' +
     'ORDER BY p.slug;'],
    '', OutText, ErrText, ExitCode) then
    Exit;
  if ExitCode <> 0 then
    Exit;

  Lines := TStringList.Create;
  try
    Lines.Text := StringReplace(OutText, #13, '', [rfReplaceAll]);
    Count := 0;
    for P := 0 to Lines.Count - 1 do
    begin
      Line := Trim(Lines[P]);
      if Line = '' then
        Continue;
      TabPos := Pos(#9, Line);
      if TabPos <= 0 then
        Continue;
      Opt.Code := Copy(Line, 1, TabPos - 1);
      Opt.Name := Copy(Line, TabPos + 1, MaxInt);
      if (Opt.Code = '') or (Opt.Name = '') then
        Continue;
      Inc(Count);
      SetLength(Result, Count);
      Result[Count - 1] := Opt;
    end;
  finally
    Lines.Free;
  end;
end;

function ListSourceTextOptionsForBookFromIndex(const BookCode: string): TSourceTextOptionList;
var
  OutText, ErrText, Line, QBook: string;
  ExitCode, I, J, Count: Integer;
  Lines, Parts: TStringList;
  Installed: TSourceTextOptionList;
  Opt: TSourceTextOption;
begin
  SetLength(Result, 0);
  if not FileExists(GetIndexSQLitePath) then
    Exit;

  QBook := StringReplace(LowerCase(Trim(BookCode)), '''', '''''', [rfReplaceAll]);
  if QBook = '' then
    Exit;

  if not RunCommandCapture('sqlite3',
    [GetIndexSQLitePath,
     'SELECT sl.slug || char(9) || sl.name || char(9) || p.slug || char(9) || p.name || char(9) || r.slug || char(9) || r.name ' +
     'FROM resource r ' +
     'JOIN project p ON p.id = r.project_id ' +
     'JOIN source_language sl ON sl.id = p.source_language_id ' +
     'WHERE lower(p.slug) = ''' + QBook + ''' ' +
     'AND r.type = ''book'' ' +
     'AND lower(r.slug) NOT IN (''tn'', ''tq'') ' +
     'ORDER BY sl.slug, r.slug;'],
    '', OutText, ErrText, ExitCode) then
    Exit;
  if ExitCode <> 0 then
    Exit;

  Installed := ListSourceTextOptions;

  Lines := TStringList.Create;
  Parts := TStringList.Create;
  try
    Parts.StrictDelimiter := True;
    Parts.Delimiter := #9;
    Lines.Text := StringReplace(OutText, #13, '', [rfReplaceAll]);
    Count := 0;
    for I := 0 to Lines.Count - 1 do
    begin
      Line := Trim(Lines[I]);
      if Line = '' then
        Continue;
      Parts.DelimitedText := Line;
      if Parts.Count < 6 then
        Continue;

      Opt.SourceLangCode := Parts[0];
      Opt.SourceLangName := Parts[1];
      Opt.BookCode := Parts[2];
      Opt.BookName := Parts[3];
      Opt.ResourceID := Parts[4];
      Opt.ResourceName := Parts[5];
      Opt.SourceDir := '';

      { Keep only source texts that are installed locally. }
      for J := 0 to Length(Installed) - 1 do
        if (CompareText(Installed[J].SourceLangCode, Opt.SourceLangCode) = 0) and
           (CompareText(Installed[J].BookCode, Opt.BookCode) = 0) and
           (CompareText(Installed[J].ResourceID, Opt.ResourceID) = 0) then
        begin
          Opt.SourceDir := Installed[J].SourceDir;
          Break;
        end;
      if Opt.SourceDir = '' then
        Continue;

      Inc(Count);
      SetLength(Result, Count);
      Result[Count - 1] := Opt;
    end;
  finally
    Parts.Free;
    Lines.Free;
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
  Caption := 'Select Target Language';

  FAll := AAll;
  SetLength(FVisible, 0);

  lblCode := TLabel.Create(Self);
  lblCode.Parent := Self;
  lblCode.Left := 12;
  lblCode.Top := 12;
  lblCode.Caption := 'Language code';

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
  lblName.Caption := 'Language name';

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
  btnOK.Caption := 'OK';
  btnOK.ModalResult := mrNone;
  btnOK.Anchors := [akRight, akBottom];
  btnOK.OnClick := @btnOKClick;

  btnCancel := TButton.Create(Self);
  btnCancel.Parent := Self;
  btnCancel.Left := 460;
  btnCancel.Top := 402;
  btnCancel.Width := 80;
  btnCancel.Caption := 'Cancel';
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
  I: Integer;
  Code: string;
begin
  Code := Trim(edtCode.Text);
  for I := 0 to Length(FAll) - 1 do
    if SameText(FAll[I].Code, Code) then
    begin
      edtCode.Text := FAll[I].Code;
      edtName.Text := FAll[I].Name;
      ModalResult := mrOK;
      Exit;
    end;
  MessageDlg('Please select a valid language code from the list.', mtWarning, [mbOK], 0);
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
    MessageDlg('No target languages found in index.sqlite.', mtError, [mbOK], 0);
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
  I: Integer;
begin
  inherited Create(AOwner);
  Position := poScreenCenter;
  Width := 620;
  Height := 480;
  BorderIcons := [biSystemMenu];
  Caption := 'Select Book';

  FAll := AAll;

  lst := TListBox.Create(Self);
  lst.Parent := Self;
  lst.Left := 12;
  lst.Top := 12;
  lst.Width := 596;
  lst.Height := 400;
  lst.Anchors := [akTop, akLeft, akRight, akBottom];
  lst.OnDblClick := @lstDblClick;

  for I := 0 to Length(FAll) - 1 do
    lst.Items.Add(FAll[I].Code + '  -  ' + FAll[I].Name);
  if lst.Items.Count > 0 then
    lst.ItemIndex := 0;

  btnOK := TButton.Create(Self);
  btnOK.Parent := Self;
  btnOK.Left := 436;
  btnOK.Top := 420;
  btnOK.Width := 80;
  btnOK.Caption := 'OK';
  btnOK.ModalResult := mrNone;
  btnOK.Anchors := [akRight, akBottom];
  btnOK.OnClick := @btnOKClick;

  btnCancel := TButton.Create(Self);
  btnCancel.Parent := Self;
  btnCancel.Left := 528;
  btnCancel.Top := 420;
  btnCancel.Width := 80;
  btnCancel.Caption := 'Cancel';
  btnCancel.ModalResult := mrCancel;
  btnCancel.Anchors := [akRight, akBottom];
end;

procedure TBookPickerForm.btnOKClick(Sender: TObject);
begin
  if (lst.ItemIndex < 0) or (lst.ItemIndex >= Length(FAll)) then
  begin
    MessageDlg('Please select a book.', mtWarning, [mbOK], 0);
    Exit;
  end;
  ModalResult := mrOK;
end;

procedure TBookPickerForm.lstDblClick(Sender: TObject);
begin
  btnOKClick(Sender);
end;

function TBookPickerForm.SelectedBook(out BookCode, BookName: string): Boolean;
begin
  Result := False;
  BookCode := '';
  BookName := '';
  if (lst.ItemIndex < 0) or (lst.ItemIndex >= Length(FAll)) then
    Exit;
  BookCode := FAll[lst.ItemIndex].Code;
  BookName := FAll[lst.ItemIndex].Name;
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
    MessageDlg('No source books found in index.sqlite.', mtError, [mbOK], 0);
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
  Caption := 'Select Source Text';

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
  btnOK.Caption := 'OK';
  btnOK.ModalResult := mrNone;
  btnOK.Anchors := [akRight, akBottom];
  btnOK.OnClick := @btnOKClick;

  btnCancel := TButton.Create(Self);
  btnCancel.Parent := Self;
  btnCancel.Left := 668;
  btnCancel.Top := 420;
  btnCancel.Width := 80;
  btnCancel.Caption := 'Cancel';
  btnCancel.ModalResult := mrCancel;
  btnCancel.Anchors := [akRight, akBottom];
end;

procedure TSourcePickerForm.btnOKClick(Sender: TObject);
begin
  if (lst.ItemIndex < 0) or (lst.ItemIndex >= Length(FAll)) then
  begin
    MessageDlg('Please select a source text.', mtWarning, [mbOK], 0);
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
    MessageDlg('No installed source texts found for book "' + Trim(BookCode) +
      '". (Excluded: tn, tq)', mtError, [mbOK], 0);
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

function BuildManifestJSON(const TargetLangCode, TargetLangName: string;
  const SourceOpt: TSourceTextOption): TJSONObject;
var
  TargetObj, ProjectObj, TypeObj, ResourceObj, GeneratorObj, SourceObj: TJSONObject;
  SourcesArr, TranslatorsArr, FinishedArr: TJSONArray;
begin
  Result := TJSONObject.Create;
  Result.Add('package_version', 8);
  Result.Add('format', 'usfm');

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
  ProjectObj.Add('id', SourceOpt.BookCode);
  ProjectObj.Add('name', SourceOpt.BookName);
  Result.Add('project', ProjectObj);

  TypeObj := TJSONObject.Create;
  TypeObj.Add('id', PROJECT_TYPE_ID);
  TypeObj.Add('name', PROJECT_TYPE_NAME);
  Result.Add('type', TypeObj);

  ResourceObj := TJSONObject.Create;
  ResourceObj.Add('id', NON_GL_RESOURCE_ID);
  ResourceObj.Add('name', NON_GL_RESOURCE_NAME);
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
  const SourceOpt: TSourceTextOption; out ProjectDir: string;
  out ErrorMsg: string): Boolean;
var
  DirName, FullDir, ManifestPath, LicenseSrc, LicenseDst: string;
  Manifest: TJSONObject;
  SL: TStringList;
  GitErr: string;
begin
  Result := False;
  ErrorMsg := '';
  ProjectDir := '';

  DirName := TargetLangCode + '_' + SourceOpt.BookCode + '_' +
    PROJECT_TYPE_ID + '_' + NON_GL_RESOURCE_ID;
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

  Manifest := BuildManifestJSON(TargetLangCode, TargetLangName, SourceOpt);
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

  LicenseSrc := FindLicenseFile(SourceOpt.SourceDir);
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
