unit MainForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, Math,
  ExtCtrls, StdCtrls, Buttons, ComCtrls, Menus, LCLType, LCLIntf, FileUtil,
  fpjson, jsonparser,
  Globals, ProjectScanner, ProjectEditForm, ProjectCreator, ProjectManager,
  TStudioPackage, SplashScreen, AppSettings, SettingsForm, ThemePalette, UIFonts,
  AppLog, UserProfile, LoginForm, GiteaClient, ImportForm, USFMExporter, GitUtils,
  DataPaths, USFMUtils, BibleBook, BibleChapter, DevToolsForm;

resourcestring
  rsProjectDetailsTitle = 'Project Details';
  rsProjectLabel = 'Project: ';
  rsTargetLanguageLabel = 'Target Language: ';
  rsResourceTypeLabel = 'Resource type: ';
  rsProgressLabel = 'Progress: ';
  rsIssuesLabel = 'Issues: ';
  rsIssuesNone = 'none';
  rsTranslatorsLabel = 'Translators:';
  rsDismiss = 'Dismiss';
  rsExportUp = '↑ Export';
  rsNone = '(none)';
  rsExportFilter = 'Translation Studio Package (*.tstudio)|*.tstudio|All files|*.*';
  rsTStudioExt = 'tstudio';
  rsExportFailedPrefix = 'Export failed: ';
  rsExportedPrefix = 'Exported: ';
  rsCurrentUserPrefix = 'Current User: ';
  rsLogout = '(Logout)';
  rsNoUser = 'Not logged in';
  rsLogoutConfirm = 'Are you sure you want to log out?';
  rsSplashBuildingHome = 'Building home screen...';
  rsSplashLoadingProjects = 'Loading projects...';
  rsSplashCheckingSources = 'Checking required source texts...';
  rsSplashScanningFolders = 'Scanning project folders...';
  rsSplashPreparingResources = 'Preparing project resources...';
  rsSplashRenderingList = 'Rendering project list...';
  rsSomeSourcesCouldNotBePreparedFmt = 'Some project sources could not be prepared (%d). First error: %s';
  rsNoProjectsFound = 'No projects found';
  rsProjectsFoundWithIssuesFmt = '%d project(s) found (%d with issues)';
  rsProjectsFoundFmt = '%d project(s) found';
  rsProjectCannotOpenUntilIssuesFixedPrefix = 'Project cannot be opened until issues are fixed: ';
  rsProjectOpenSafelyAbortedPrefix = 'Project could not be opened and was safely aborted: ';
  rsHintDetails = 'details';
  rsProjectCreatedPrefix = 'Project created: ';
  rsTypeTextPrefix = 'Text ';
  rsTypeUnknown = 'Unknown';
  rsMenuUpdate = 'Update';
  rsMenuImport = 'Import';
  rsMenuFeedback = 'Feedback';
  rsMenuLogout = 'Logout';
  rsMenuSettings = 'Settings';
  rsMenuDevTools = 'Developer Tools';
  rsFeedbackTitle = 'Feedback';
  rsFeedbackWarning = 'This will use your internet connection.';
  rsFeedbackHint = 'Describe the problem you are experiencing';
  rsFeedbackSend = 'Send';
  rsFeedbackCancel = 'Cancel';
  rsFeedbackSent = 'Feedback sent. Thank you!';
  rsFeedbackFailed = 'Could not send feedback: ';
  rsFeedbackEmpty = 'Please describe the problem before sending.';
  rsUpdateNotImplemented = 'Update check is not yet implemented.';
  rsUSFMExportFilter = 'USFM Files (*.usfm)|*.usfm|All files|*.*';
  rsUSFMExt = 'usfm';
  rsUSFMExportedPrefix = 'USFM exported: ';
  rsUSFMExportFailedPrefix = 'USFM export failed: ';
  rsImportTStudioFilter = 'Translation Studio Package (*.tstudio)|*.tstudio|All files|*.*';
  rsImportSuccessPrefix = 'Project imported: ';
  rsImportFailedPrefix = 'Import failed: ';
  rsImportOverwriteConfirm = 'A project with this name already exists. Overwrite?';
  rsImportMergedWithConflicts = 'Project merged. There are conflicts that need to be resolved. Open the project to resolve them.';
  rsUploadSuccessPrefix = 'Uploaded to server: ';
  rsUploadFailedPrefix = 'Upload failed: ';
  rsUploadRequiresServer = 'You must be logged in with a server account to upload.';
  rsServerSearchTitle = 'Import from Server';
  rsServerSearchLabel = 'Search (username or lang_book):';
  rsServerSearchBtn = 'Search';
  rsServerImportBtn = 'Import';
  rsServerNoResults = 'No repositories found.';
  rsUSFMImportFilter = 'USFM Files (*.usfm;*.txt)|*.usfm;*.txt|All files|*.*';
  rsSourceImportTitle = 'Import Source Text';
  rsSourceImportSuccess = 'Source text imported: ';
  rsSourceImportFailed = 'Source text import failed: ';
  rsSourceImportInvalidDir = 'Selected directory does not contain a valid resource container (missing package.json or content/toc.yml).';
  rsDeleteProject = 'Delete';
  rsConfirmDeleteProject = 'Are you sure you want to permanently delete this project? This cannot be undone.';
  rsProjectDeletedPrefix = 'Project deleted: ';
  rsChange = 'Change';
  rsChangeResTypeTitle = 'Change Resource Type';

type
  TMainWindow = class(TForm)
    AddProjectCircle: TShape;
    cmbSortBy: TComboBox;
    cmbSortColumnBy: TComboBox;
    lblSortBy: TLabel;
    lblSortColumnBy: TLabel;
    lblProjectColumn: TLabel;
    lblTypeColumn: TLabel;
    lblLanguageColumn: TLabel;
    lblProgressColumn: TLabel;
    HeaderPanel: TPanel;
    LeftRail: TPanel;
    lblAppName: TLabel;
    lblCurrentUser: TLabel;
    btnLogout: TLabel;
    ContentPanel: TPanel;
    lblProjectsHeading: TLabel;
    ProjectsTablePanel: TPanel;
    ProjectScrollBox: TScrollBox;
    WelcomePanel: TPanel;
    lblWelcome: TLabel;
    lblWelcomeMsg: TLabel;
    btnStartProject: TButton;
    btnAddProject: TSpeedButton;
    btnMenu: TSpeedButton;
    StatusBar: TStatusBar;
    procedure btnAddProjectClick(Sender: TObject);
    procedure btnMenuClick(Sender: TObject);
    procedure btnStartProjectClick(Sender: TObject);
    procedure FormActivate(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormResize(Sender: TObject);
  private
    FProjects: TProjectSummaryList;
    FFirstLoadDone: Boolean;
    procedure UpdateLayout;
    procedure EnsureSourcesForProjects;
    procedure ScanAndDisplayProjects;
    procedure QueueProjectRescan;
    procedure AsyncProjectRescan(Data: PtrInt);
    procedure RefreshProjectListUI;
    procedure ClearProjectRows;
    procedure CreateProjectRow(const S: TProjectSummary; Idx: Integer);
    procedure SortProjects;
    procedure SortComboChange(Sender: TObject);
    procedure ApplyTheme;
    procedure OpenProjectAtIndex(Idx: Integer);
    procedure AsyncOpenProject(Data: PtrInt);
    procedure ShowProjectDetails(Idx: Integer);
    procedure ProjectRowClick(Sender: TObject);
    procedure InfoButtonClick(Sender: TObject);
    procedure PieChartPaint(Sender: TObject);
    procedure StatusBarDrawPanel(AStatusBar: TStatusBar; Panel: TStatusPanel;
      const Rect: TRect);
    procedure StartNewProjectFlow;
    procedure GlobalExceptionHandler(Sender: TObject; E: Exception);
    procedure EnsureUserProfile;
    procedure UpdateUserDisplay;
    procedure DoLogout;
    procedure LogoutClick(Sender: TObject);
    procedure MenuUpdateClick(Sender: TObject);
    procedure MenuImportClick(Sender: TObject);
    procedure MenuFeedbackClick(Sender: TObject);
    procedure MenuSettingsClick(Sender: TObject);
    procedure MenuDevToolsClick(Sender: TObject);
    procedure UpdateDevToolsMenuItem;
    procedure ShowFeedbackDialog;
    procedure DoImportProjectFile;
    procedure DoImportFromServer;
    procedure DoImportUSFMFile;
    procedure DoImportSourceText;
  private
    FMainMenu: TPopupMenu;
  public
    FCurrentUser: TUserProfile;
    procedure DoUploadToServer(const ASummary: TProjectSummary);
    procedure DoExportUSFM(const ASummary: TProjectSummary);
  end;

var
  MainWindow: TMainWindow;

implementation

uses
  Grids;

{$R *.lfm}

type
  TProjectDetailsWindow = class(TForm)
  private
    FSummary: TProjectSummary;
    FDirty: Boolean;
    lblTitle: TLabel;
    lblProject: TLabel;
    lblTargetLang: TLabel;
    lblChangeLang: TLabel;
    lblResourceType: TLabel;
    lblChangeResType: TLabel;
    lblProgress: TLabel;
    lblIssues: TLabel;
    lblTranslators: TLabel;
    memTranslators: TMemo;
    btnDismiss: TButton;
    btnExport: TButton;
    btnDelete: TButton;
    function LoadTranslatorsText: string;
    procedure btnDismissClick(Sender: TObject);
    procedure btnExportClick(Sender: TObject);
    procedure btnDeleteClick(Sender: TObject);
    procedure ChangeLangClick(Sender: TObject);
    procedure ChangeResTypeClick(Sender: TObject);
    procedure SaveManifestChanges;
    function RenameProjectDir: Boolean;
  public
    constructor CreateDetails(AOwner: TComponent; const ASummary: TProjectSummary);
  end;

function ProjectDisplayName(const S: TProjectSummary): string;
begin
  { Use canonical app-language book name for Bible projects (English for now). }
  Result := CanonicalBookName(S.BookCode);
  if Result <> '' then
    Exit;
  Result := Trim(S.BookName);
  if Result = '' then
    Result := Trim(S.DirName);
  if Result = '' then
    Result := ExtractFileName(ExcludeTrailingPathDelimiter(S.FullPath));
  if Result = '' then
    Result := rsTypeUnknown;
end;

function ProjectProgressPct(const S: TProjectSummary): Integer;
begin
  if S.TotalChunks > 0 then
    Result := (S.FinishedChunks * 100) div S.TotalChunks
  else
    Result := 0;
end;

const
  BOOK_ORDER: array[0..65] of string = (
    'gen','exo','lev','num','deu','jos','jdg','rut','1sa','2sa','1ki','2ki',
    '1ch','2ch','ezr','neh','est','job','psa','pro','ecc','sng','isa','jer',
    'lam','ezk','dan','hos','jol','amo','oba','jon','mic','nam','hab','zep',
    'hag','zec','mal','mat','mrk','luk','jhn','act','rom','1co','2co','gal',
    'eph','php','col','1th','2th','1ti','2ti','tit','phm','heb','jas','1pe',
    '2pe','1jn','2jn','3jn','jud','rev'
  );

function CanonicalBookIndex(const BookCode: string): Integer;
var
  I: Integer;
  C: string;
begin
  C := LowerCase(Trim(BookCode));
  for I := Low(BOOK_ORDER) to High(BOOK_ORDER) do
    if BOOK_ORDER[I] = C then
      Exit(I);
  Result := 9999;
end;

{ USFM book number: OT 01-39, NT 41-67 (40 is skipped). Returns 0 if unknown. }
function USFMBookNumber(const BookCode: string): Integer;
var
  Idx: Integer;
begin
  Idx := CanonicalBookIndex(BookCode);
  if Idx = 9999 then
    Exit(0);
  if Idx <= 38 then
    Result := Idx + 1       { OT: 01-39 }
  else
    Result := Idx + 2;      { NT: 41-67 (skip 40) }
end;

function CompareProjectKey(const A, B: TProjectSummary; ProjectSortMode: Integer): Integer;
var
  IA, IB: Integer;
begin
  if ProjectSortMode = 0 then
  begin
    IA := CanonicalBookIndex(A.BookCode);
    IB := CanonicalBookIndex(B.BookCode);
    Result := IA - IB;
    if Result <> 0 then
      Exit;
  end;
  Result := CompareText(ProjectDisplayName(A), ProjectDisplayName(B));
end;

function CompareLanguageKey(const A, B: TProjectSummary): Integer;
begin
  Result := CompareText(A.TargetLangName, B.TargetLangName);
  if Result = 0 then
    Result := CompareText(A.TargetLangCode, B.TargetLangCode);
end;

function CompareProjects(const A, B: TProjectSummary; SortByMode, ProjectSortMode: Integer): Integer;
begin
  case SortByMode of
    1: begin
      Result := CompareProjectKey(A, B, ProjectSortMode);
      if Result = 0 then
        Result := CompareLanguageKey(A, B);
    end;
    2: begin
      Result := ProjectProgressPct(A) - ProjectProgressPct(B);
      if Result = 0 then
        Result := CompareProjectKey(A, B, ProjectSortMode);
      if Result = 0 then
        Result := CompareLanguageKey(A, B);
    end;
  else
    begin
      Result := CompareLanguageKey(A, B);
      if Result = 0 then
        Result := CompareProjectKey(A, B, ProjectSortMode);
    end;
  end;

  if Result = 0 then
    Result := CompareText(A.DirName, B.DirName);
end;

procedure QuickSortProjects(var Arr: TProjectSummaryList; L, R, SortByMode,
  ProjectSortMode: Integer);
var
  I, J: Integer;
  P, T: TProjectSummary;
begin
  I := L;
  J := R;
  P := Arr[(L + R) div 2];
  repeat
    while CompareProjects(Arr[I], P, SortByMode, ProjectSortMode) < 0 do
      Inc(I);
    while CompareProjects(Arr[J], P, SortByMode, ProjectSortMode) > 0 do
      Dec(J);
    if I <= J then
    begin
      T := Arr[I];
      Arr[I] := Arr[J];
      Arr[J] := T;
      Inc(I);
      Dec(J);
    end;
  until I > J;
  if L < J then
    QuickSortProjects(Arr, L, J, SortByMode, ProjectSortMode);
  if I < R then
    QuickSortProjects(Arr, I, R, SortByMode, ProjectSortMode);
end;

constructor TProjectDetailsWindow.CreateDetails(AOwner: TComponent;
  const ASummary: TProjectSummary);
var
  ProgressPct: Integer;
  P: TThemePalette;
  Y: Integer;
begin
  inherited Create(AOwner);
  FSummary := ASummary;
  P := GetThemePalette(GetEffectiveTheme);
  Position := poScreenCenter;
  Width := 520;
  Height := 460;
  BorderIcons := [biSystemMenu];
  Caption := rsProjectDetailsTitle;
  Color := P.PanelBg;

  { Title: "BookName — LangName" matching v1 }
  lblTitle := TLabel.Create(Self);
  lblTitle.Parent := Self;
  lblTitle.Left := 24;
  lblTitle.Top := 20;
  lblTitle.Font.Style := [fsBold];
  lblTitle.Font.Height := -24;
  lblTitle.Font.Color := P.TextPrimary;
  lblTitle.Caption := ProjectDisplayName(FSummary) + ' — ' + FSummary.TargetLangName;

  Y := 68;

  { Project: BookName (bookcode) }
  lblProject := TLabel.Create(Self);
  lblProject.Parent := Self;
  lblProject.Left := 24;
  lblProject.Top := Y;
  lblProject.Font.Height := -16;
  lblProject.Font.Color := P.TextSecondary;
  lblProject.Caption := rsProjectLabel + ProjectDisplayName(FSummary) +
    ' (' + LowerCase(FSummary.BookCode) + ')';
  Inc(Y, 26);

  { Target Language: LangName (langcode)    Change }
  lblTargetLang := TLabel.Create(Self);
  lblTargetLang.Parent := Self;
  lblTargetLang.Left := 24;
  lblTargetLang.Top := Y;
  lblTargetLang.Font.Height := -16;
  lblTargetLang.Font.Color := P.TextSecondary;
  lblTargetLang.Caption := rsTargetLanguageLabel + FSummary.TargetLangName +
    ' (' + FSummary.TargetLangCode + ')';
  lblTargetLang.AutoSize := True;

  lblChangeLang := TLabel.Create(Self);
  lblChangeLang.Parent := Self;
  lblChangeLang.Top := Y;
  lblChangeLang.Font.Height := -16;
  lblChangeLang.Font.Color := clTeal;
  lblChangeLang.Font.Style := [fsUnderline];
  lblChangeLang.Caption := rsChange;
  lblChangeLang.Cursor := crHandPoint;
  lblChangeLang.OnClick := @ChangeLangClick;
  lblChangeLang.AutoSize := True;
  lblChangeLang.BorderSpacing.Left := 16;
  lblChangeLang.AnchorSideLeft.Control := lblTargetLang;
  lblChangeLang.AnchorSideLeft.Side := asrRight;
  Inc(Y, 26);

  { Resource type:    Change }
  lblResourceType := TLabel.Create(Self);
  lblResourceType.Parent := Self;
  lblResourceType.Left := 24;
  lblResourceType.Top := Y;
  lblResourceType.Font.Height := -16;
  lblResourceType.Font.Color := P.TextSecondary;
  lblResourceType.Caption := rsResourceTypeLabel + FSummary.ResourceType;
  lblResourceType.AutoSize := True;

  lblChangeResType := TLabel.Create(Self);
  lblChangeResType.Parent := Self;
  lblChangeResType.Top := Y;
  lblChangeResType.Font.Height := -16;
  lblChangeResType.Font.Color := clTeal;
  lblChangeResType.Font.Style := [fsUnderline];
  lblChangeResType.Caption := rsChange;
  lblChangeResType.Cursor := crHandPoint;
  lblChangeResType.OnClick := @ChangeResTypeClick;
  lblChangeResType.AutoSize := True;
  lblChangeResType.BorderSpacing.Left := 16;
  lblChangeResType.AnchorSideLeft.Control := lblResourceType;
  lblChangeResType.AnchorSideLeft.Side := asrRight;
  Inc(Y, 26);

  { Progress: }
  if FSummary.TotalChunks > 0 then
    ProgressPct := (FSummary.FinishedChunks * 100) div FSummary.TotalChunks
  else
    ProgressPct := 0;
  lblProgress := TLabel.Create(Self);
  lblProgress.Parent := Self;
  lblProgress.Left := 24;
  lblProgress.Top := Y;
  lblProgress.Font.Height := -16;
  lblProgress.Font.Color := P.TextSecondary;
  lblProgress.Caption := rsProgressLabel + IntToStr(ProgressPct) + '%';
  Inc(Y, 26);

  { Issues: only show if there are issues }
  if FSummary.HasIssues then
  begin
    lblIssues := TLabel.Create(Self);
    lblIssues.Parent := Self;
    lblIssues.Left := 24;
    lblIssues.Top := Y;
    lblIssues.Font.Height := -16;
    lblIssues.Font.Color := clRed;
    lblIssues.Caption := rsIssuesLabel + FSummary.IssueSummary;
    Inc(Y, 26);
  end;

  { Translators: }
  Inc(Y, 4);
  lblTranslators := TLabel.Create(Self);
  lblTranslators.Parent := Self;
  lblTranslators.Left := 24;
  lblTranslators.Top := Y;
  lblTranslators.Font.Height := -16;
  lblTranslators.Font.Color := P.TextSecondary;
  lblTranslators.Caption := rsTranslatorsLabel;
  Inc(Y, 24);

  memTranslators := TMemo.Create(Self);
  memTranslators.Parent := Self;
  memTranslators.Left := 24;
  memTranslators.Top := Y;
  memTranslators.Width := 464;
  memTranslators.Height := 120;
  memTranslators.ReadOnly := False;
  memTranslators.ScrollBars := ssVertical;
  memTranslators.Color := P.MemoBg;
  memTranslators.Font.Color := P.TextPrimary;
  memTranslators.Lines.Text := LoadTranslatorsText;

  { Bottom buttons: Delete (left), Dismiss + Export (right) }
  btnDelete := TButton.Create(Self);
  btnDelete.Parent := Self;
  btnDelete.Left := 24;
  btnDelete.Top := Height - 56;
  btnDelete.Width := 80;
  btnDelete.Anchors := [akLeft, akBottom];
  btnDelete.Caption := rsDeleteProject;
  btnDelete.Font.Color := clRed;
  btnDelete.OnClick := @btnDeleteClick;

  btnDismiss := TButton.Create(Self);
  btnDismiss.Parent := Self;
  btnDismiss.Left := Width - 240;
  btnDismiss.Top := Height - 56;
  btnDismiss.Width := 96;
  btnDismiss.Anchors := [akRight, akBottom];
  btnDismiss.Caption := rsDismiss;
  btnDismiss.OnClick := @btnDismissClick;

  btnExport := TButton.Create(Self);
  btnExport.Parent := Self;
  btnExport.Left := Width - 130;
  btnExport.Top := Height - 56;
  btnExport.Width := 104;
  btnExport.Anchors := [akRight, akBottom];
  btnExport.Caption := rsExportUp;
  btnExport.OnClick := @btnExportClick;
end;

function TProjectDetailsWindow.LoadTranslatorsText: string;
var
  SL: TStringList;
  Data: TJSONData;
  Obj: TJSONObject;
  Node: TJSONData;
  Arr: TJSONArray;
  I: Integer;
begin
  Result := '';
  if not FileExists(IncludeTrailingPathDelimiter(FSummary.FullPath) + 'manifest.json') then
    Exit(rsNone);

  SL := TStringList.Create;
  try
    SL.LoadFromFile(IncludeTrailingPathDelimiter(FSummary.FullPath) + 'manifest.json');
    Data := GetJSON(SL.Text);
    if not (Data is TJSONObject) then
    begin
      Data.Free;
      Exit(rsNone);
    end;
    Obj := TJSONObject(Data);
    try
      Node := Obj.Find('translators');
      if not (Node is TJSONArray) then
        Exit(rsNone);
      Arr := TJSONArray(Node);
      if Arr.Count = 0 then
        Exit(rsNone);
      for I := 0 to Arr.Count - 1 do
      begin
        if Result <> '' then
          Result := Result + LineEnding;
        Result := Result + Arr.Strings[I];
      end;
    finally
      Obj.Free;
    end;
  finally
    SL.Free;
  end;
end;

procedure TProjectDetailsWindow.btnDeleteClick(Sender: TObject);
var
  ProjectDir: string;
begin
  if MessageDlg(rsConfirmDeleteProject, mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
    Exit;
  ProjectDir := ExcludeTrailingPathDelimiter(FSummary.FullPath);
  if DirectoryExists(ProjectDir) then
  begin
    if not DeleteDirectory(ProjectDir, False) then
    begin
      ShowMessage('Could not delete project directory.');
      Exit;
    end;
  end;
  ModalResult := mrOK;
end;

procedure TProjectDetailsWindow.ChangeLangClick(Sender: TObject);
var
  NewCode, NewName: string;
begin
  if not PromptForTargetLanguage(NewCode, NewName) then
    Exit;
  if (NewCode = FSummary.TargetLangCode) and (NewName = FSummary.TargetLangName) then
    Exit;
  FSummary.TargetLangCode := NewCode;
  FSummary.TargetLangName := NewName;
  lblTargetLang.Caption := rsTargetLanguageLabel + FSummary.TargetLangName +
    ' (' + FSummary.TargetLangCode + ')';
  lblTitle.Caption := ProjectDisplayName(FSummary) + ' — ' + FSummary.TargetLangName;
  FDirty := True;
end;

procedure TProjectDetailsWindow.ChangeResTypeClick(Sender: TObject);
var
  Dlg: TForm;
  Lst: TListBox;
  BtnOK, BtnCancel: TButton;
  P: TThemePalette;
  Idx: Integer;
begin
  P := GetThemePalette(GetEffectiveTheme);
  Dlg := TForm.Create(Self);
  try
    Dlg.Position := poScreenCenter;
    Dlg.Width := 300;
    Dlg.Height := 260;
    Dlg.Caption := rsChangeResTypeTitle;
    Dlg.BorderIcons := [biSystemMenu];
    Dlg.Color := P.PanelBg;

    Lst := TListBox.Create(Dlg);
    Lst.Parent := Dlg;
    Lst.Left := 20;
    Lst.Top := 20;
    Lst.Width := 260;
    Lst.Height := 150;
    Lst.Items.Add('reg — Regular');
    Lst.Items.Add('ulb — Unlocked Literal Bible');
    Lst.Items.Add('udb — Unlocked Dynamic Bible');
    { Pre-select current }
    if LowerCase(FSummary.ResourceType) = 'ulb' then
      Lst.ItemIndex := 1
    else if LowerCase(FSummary.ResourceType) = 'udb' then
      Lst.ItemIndex := 2
    else
      Lst.ItemIndex := 0;

    BtnOK := TButton.Create(Dlg);
    BtnOK.Parent := Dlg;
    BtnOK.Left := 100;
    BtnOK.Top := 185;
    BtnOK.Width := 80;
    BtnOK.Caption := 'OK';
    BtnOK.ModalResult := mrOK;
    BtnOK.Default := True;

    BtnCancel := TButton.Create(Dlg);
    BtnCancel.Parent := Dlg;
    BtnCancel.Left := 190;
    BtnCancel.Top := 185;
    BtnCancel.Width := 80;
    BtnCancel.Caption := 'Cancel';
    BtnCancel.ModalResult := mrCancel;
    BtnCancel.Cancel := True;

    if Dlg.ShowModal <> mrOK then
      Exit;
    Idx := Lst.ItemIndex;
    if Idx < 0 then
      Exit;
  finally
    Dlg.Free;
  end;

  case Idx of
    1: FSummary.ResourceType := 'ulb';
    2: FSummary.ResourceType := 'udb';
  else
    FSummary.ResourceType := 'reg';
  end;
  lblResourceType.Caption := rsResourceTypeLabel + FSummary.ResourceType;
  FDirty := True;
end;

procedure TProjectDetailsWindow.SaveManifestChanges;
var
  ManifestPath: string;
  SL: TStringList;
  Data: TJSONData;
  Manifest, TargetLangObj, ResourceObj: TJSONObject;
  TransArr: TJSONArray;
  I: Integer;
  Line: string;
begin
  ManifestPath := IncludeTrailingPathDelimiter(FSummary.FullPath) + 'manifest.json';
  if not FileExists(ManifestPath) then
    Exit;

  SL := TStringList.Create;
  try
    SL.LoadFromFile(ManifestPath);
    Data := GetJSON(SL.Text);
    if not (Data is TJSONObject) then
    begin
      Data.Free;
      Exit;
    end;
    Manifest := TJSONObject(Data);
    try
      { Update target_language.id and name }
      if Manifest.FindPath('target_language') is TJSONObject then
      begin
        TargetLangObj := TJSONObject(Manifest.FindPath('target_language'));
        TargetLangObj.Strings['id'] := FSummary.TargetLangCode;
        TargetLangObj.Strings['name'] := FSummary.TargetLangName;
      end;

      { Update resource.id and name }
      if Manifest.FindPath('resource') is TJSONObject then
      begin
        ResourceObj := TJSONObject(Manifest.FindPath('resource'));
        ResourceObj.Strings['id'] := FSummary.ResourceType;
        case LowerCase(FSummary.ResourceType) of
          'ulb': ResourceObj.Strings['name'] := 'Unlocked Literal Bible';
          'udb': ResourceObj.Strings['name'] := 'Unlocked Dynamic Bible';
        else
          ResourceObj.Strings['name'] := 'Regular';
        end;
      end;

      { Update translators array from memo }
      TransArr := TJSONArray.Create;
      for I := 0 to memTranslators.Lines.Count - 1 do
      begin
        Line := Trim(memTranslators.Lines[I]);
        if Line <> '' then
          TransArr.Add(Line);
      end;
      { Remove old translators and add new }
      I := Manifest.IndexOfName('translators');
      if I >= 0 then
        Manifest.Delete(I);
      Manifest.Add('translators', TransArr);

      { Write back }
      SL.Text := Manifest.FormatJSON;
      SL.SaveToFile(ManifestPath);
    finally
      Manifest.Free;
    end;
  finally
    SL.Free;
  end;
end;

function TProjectDetailsWindow.RenameProjectDir: Boolean;
var
  NewDirName, BasePath, OldPath, NewPath, Err: string;
  Choice: TDuplicateChoice;
  HasConflicts: Boolean;
begin
  Result := True;
  NewDirName := CanonicalProjectDirName(FSummary.TargetLangCode, FSummary.BookCode,
    FSummary.TypeID, FSummary.ResourceType);
  if NewDirName = '' then
    Exit;
  OldPath := ExcludeTrailingPathDelimiter(FSummary.FullPath);
  BasePath := ExtractFilePath(OldPath);
  NewPath := BasePath + NewDirName;
  if OldPath = NewPath then
    Exit; { no rename needed }

  if DirectoryExists(NewPath) then
  begin
    { Existing project at target — offer merge/overwrite/cancel }
    Choice := ShowDuplicateProjectDialog;
    case Choice of
      dcCancel:
      begin
        Result := False;
        Exit;
      end;
      dcOverwrite:
      begin
        { Remove existing, then rename }
        if not DeleteDirectory(NewPath, False) then
        begin
          ShowMessage('Could not remove existing project directory.');
          Result := False;
          Exit;
        end;
      end;
      dcMerge:
      begin
        { Commit our changes, then merge old into new location }
        EnsureProjectCommitted(OldPath, Err);
        EnsureProjectCommitted(NewPath, Err);
        if not MergeImportedProject(NewPath, OldPath,
          HasConflicts, Err) then
        begin
          ShowMessage(rsImportFailedPrefix + Err);
          Result := False;
          Exit;
        end;
        { Remove old dir after successful merge }
        DeleteDirectory(OldPath, False);
        FSummary.FullPath := IncludeTrailingPathDelimiter(NewPath);
        FSummary.DirName := NewDirName;
        if HasConflicts then
          ShowMessage(rsImportMergedWithConflicts);
        Exit;
      end;
    end;
  end;

  if not RenameFile(OldPath, NewPath) then
  begin
    ShowMessage('Could not rename project directory.');
    Result := False;
    Exit;
  end;
  FSummary.FullPath := IncludeTrailingPathDelimiter(NewPath);
  FSummary.DirName := NewDirName;
end;

procedure TProjectDetailsWindow.btnDismissClick(Sender: TObject);
begin
  { Check if translators changed even without explicit Change click }
  if memTranslators.Modified then
    FDirty := True;
  if FDirty then
  begin
    SaveManifestChanges;
    RenameProjectDir;
  end;
  Close;
end;

procedure TProjectDetailsWindow.btnExportClick(Sender: TObject);
var
  Choice: TExportChoice;
  SaveDlg: TSaveDialog;
  Err: string;
begin
  Choice := ShowExportDialog(IsServerUser(MainWindow.FCurrentUser));
  case Choice of
    ecTStudio:
    begin
      SaveDlg := TSaveDialog.Create(Self);
      try
        SaveDlg.Filter := rsExportFilter;
        SaveDlg.DefaultExt := rsTStudioExt;
        if FSummary.DirName <> '' then
          SaveDlg.FileName := FSummary.DirName + '.tstudio'
        else
          SaveDlg.FileName := ExtractFileName(
            ExcludeTrailingPathDelimiter(FSummary.FullPath)) + '.tstudio';
        SaveDlg.InitialDir := GetBackupLocation;
        if (SaveDlg.InitialDir = '') or not DirectoryExists(SaveDlg.InitialDir) then
          SaveDlg.InitialDir := GetEnvironmentVariable('HOME');
        if not SaveDlg.Execute then
          Exit;
        if not CreateTStudioPackage(FSummary.FullPath, SaveDlg.FileName, Err) then
        begin
          ShowMessage(rsExportFailedPrefix + Err);
          Exit;
        end;
        ShowMessage(rsExportedPrefix + SaveDlg.FileName);
      finally
        SaveDlg.Free;
      end;
    end;
    ecUSFM:
      MainWindow.DoExportUSFM(FSummary);
    ecServer:
      MainWindow.DoUploadToServer(FSummary);
  end;
end;

procedure TMainWindow.UpdateLayout;
var
  LeftMargin, TopY, BottomMargin, TableWidth, TableHeight: Integer;
  MaxTableWidth: Integer;
  Gutter, SortTop, SortLabelTop, Gap, SortWidth: Integer;
begin
  if ContentPanel.ClientWidth <= 0 then
    Exit;

  MaxTableWidth := 760;
  LeftMargin := Max(120, (ContentPanel.ClientWidth - MaxTableWidth) div 2);
  TableWidth := ContentPanel.ClientWidth - (LeftMargin * 2);
  if TableWidth < 420 then
  begin
    LeftMargin := 24;
    TableWidth := ContentPanel.ClientWidth - 48;
  end;

  TopY := 165;
  BottomMargin := 28;
  TableHeight := ContentPanel.ClientHeight - TopY - BottomMargin;
  if TableHeight < 170 then
    TableHeight := 170;

  ProjectsTablePanel.SetBounds(LeftMargin, TopY, TableWidth, TableHeight);

  Gutter := 14;
  SortLabelTop := 62;
  SortTop := 84;
  Gap := 28;
  SortWidth := (ProjectsTablePanel.Width - (Gutter * 2) - Gap) div 2;
  if SortWidth < 170 then
    SortWidth := 170;

  lblProjectsHeading.Left := ProjectsTablePanel.Left;

  lblSortBy.Left := ProjectsTablePanel.Left + Gutter;
  lblSortBy.Top := SortLabelTop;
  cmbSortBy.Left := lblSortBy.Left;
  cmbSortBy.Top := SortTop;
  cmbSortBy.Width := SortWidth;

  lblSortColumnBy.Left := cmbSortBy.Left + cmbSortBy.Width + Gap;
  lblSortColumnBy.Top := SortLabelTop;
  cmbSortColumnBy.Left := lblSortColumnBy.Left;
  cmbSortColumnBy.Top := SortTop;
  cmbSortColumnBy.Width := SortWidth;

  AddProjectCircle.Left := ProjectsTablePanel.Left + ProjectsTablePanel.Width + 20;
  if AddProjectCircle.Left + AddProjectCircle.Width > ContentPanel.ClientWidth - 8 then
    AddProjectCircle.Left := ContentPanel.ClientWidth - AddProjectCircle.Width - 8;
  btnAddProject.Left := AddProjectCircle.Left;

  lblProjectColumn.Left := ProjectsTablePanel.Left + 54;
  lblTypeColumn.Left := ProjectsTablePanel.Left + Round(ProjectsTablePanel.Width * 0.37);
  lblLanguageColumn.Left := ProjectsTablePanel.Left + Round(ProjectsTablePanel.Width * 0.53);
  lblProgressColumn.Left := ProjectsTablePanel.Left + ProjectsTablePanel.Width - 116;

  WelcomePanel.Left := (ContentPanel.ClientWidth - WelcomePanel.Width) div 2;
end;

procedure TMainWindow.FormCreate(Sender: TObject);
begin
  Application.OnException := @GlobalExceptionHandler;
  InitializeAppSettings;
  FFirstLoadDone := False;
  ApplyFontRecursive(Self, 'Noto Sans');
  UpdateStartupSplash(rsSplashBuildingHome);
  Caption := APP_NAME + ' ' + APP_VERSION;
  btnLogout.Caption := rsLogout;
  btnLogout.OnClick := @LogoutClick;
  UpdateUserDisplay;

  ProjectScrollBox.Visible := False;
  if StatusBar.Panels.Count > 0 then
    StatusBar.Panels[0].Style := psOwnerDraw;
  StatusBar.OnDrawPanel := @StatusBarDrawPanel;
  btnMenu.OnClick := @btnMenuClick;
  btnAddProject.OnClick := @btnAddProjectClick;
  btnStartProject.OnClick := @btnStartProjectClick;
  cmbSortBy.OnChange := @SortComboChange;
  cmbSortColumnBy.OnChange := @SortComboChange;

  { Build main popup menu }
  FMainMenu := TPopupMenu.Create(Self);
  FMainMenu.Items.Add(TMenuItem.Create(FMainMenu));
  FMainMenu.Items[0].Caption := rsMenuUpdate;
  FMainMenu.Items[0].OnClick := @MenuUpdateClick;
  FMainMenu.Items.Add(TMenuItem.Create(FMainMenu));
  FMainMenu.Items[1].Caption := rsMenuImport;
  FMainMenu.Items[1].OnClick := @MenuImportClick;
  FMainMenu.Items.Add(TMenuItem.Create(FMainMenu));
  FMainMenu.Items[2].Caption := '-';  { separator }
  FMainMenu.Items.Add(TMenuItem.Create(FMainMenu));
  FMainMenu.Items[3].Caption := rsMenuFeedback;
  FMainMenu.Items[3].OnClick := @MenuFeedbackClick;
  FMainMenu.Items.Add(TMenuItem.Create(FMainMenu));
  FMainMenu.Items[4].Caption := rsMenuLogout;
  FMainMenu.Items[4].OnClick := @LogoutClick;
  FMainMenu.Items.Add(TMenuItem.Create(FMainMenu));
  FMainMenu.Items[5].Caption := '-';  { separator }
  FMainMenu.Items.Add(TMenuItem.Create(FMainMenu));
  FMainMenu.Items[6].Caption := rsMenuSettings;
  FMainMenu.Items[6].OnClick := @MenuSettingsClick;
  UpdateDevToolsMenuItem;

  ApplyTheme;

  { Check for user profile — show login if none exists }
  EnsureUserProfile;

  UpdateStartupSplash(rsSplashLoadingProjects);
  UpdateLayout;
  ScanAndDisplayProjects;
end;

procedure TMainWindow.SortComboChange(Sender: TObject);
begin
  SortProjects;
  RefreshProjectListUI;
end;

procedure TMainWindow.btnMenuClick(Sender: TObject);
var
  Pt: TPoint;
begin
  { Show popup menu above the menu button }
  Pt := btnMenu.ClientToScreen(Point(btnMenu.Width + 4, 0));
  FMainMenu.PopUp(Pt.X, Pt.Y);
end;

procedure TMainWindow.btnAddProjectClick(Sender: TObject);
begin
  StartNewProjectFlow;
end;

procedure TMainWindow.btnStartProjectClick(Sender: TObject);
begin
  StartNewProjectFlow;
end;

procedure TMainWindow.FormResize(Sender: TObject);
begin
  UpdateLayout;
end;

procedure TMainWindow.FormActivate(Sender: TObject);
begin
  ApplyTheme;
end;

procedure TMainWindow.ApplyTheme;
var
  P: TThemePalette;

  procedure ForceColor(C: TWinControl; AColor: TColor);
  begin
    if C is TPanel then
    begin
      TPanel(C).ParentBackground := False;
      TPanel(C).ParentColor := False;
    end;
    C.Color := AColor;
    C.Invalidate;
  end;

begin
  P := GetThemePalette(GetEffectiveTheme);

  Color := P.WindowBg;
  ForceColor(HeaderPanel, P.HeaderBg);
  ForceColor(LeftRail, P.RailBg);
  ForceColor(ContentPanel, P.ContentBg);
  ForceColor(ProjectsTablePanel, P.PanelBg);
  ForceColor(WelcomePanel, P.PanelBg);
  ForceColor(ProjectScrollBox, P.PanelBg);
  StatusBar.Color := P.StatusBg;
  StatusBar.Font.Color := P.HeaderText;
  lblAppName.Font.Color := P.HeaderText;
  lblCurrentUser.Font.Color := P.HeaderText;
  btnLogout.Font.Color := P.HeaderText;
  lblProjectsHeading.Font.Color := P.TextPrimary;
  lblSortBy.Font.Color := P.TextMuted;
  lblSortColumnBy.Font.Color := P.TextMuted;
  lblProjectColumn.Font.Color := P.TextMuted;
  lblTypeColumn.Font.Color := P.TextMuted;
  lblLanguageColumn.Font.Color := P.TextMuted;
  lblProgressColumn.Font.Color := P.TextMuted;
  lblWelcome.Font.Color := P.TextPrimary;
  lblWelcomeMsg.Font.Color := P.TextSecondary;
  btnMenu.Font.Color := P.RailText;
  AddProjectCircle.Brush.Color := P.Accent;
  AddProjectCircle.Pen.Color := P.Accent;
  btnAddProject.Font.Color := P.TextInverse;

  { Rebuild project rows so they pick up the new palette }
  if Length(FProjects) > 0 then
    RefreshProjectListUI;

  Invalidate;
end;

procedure TMainWindow.EnsureSourcesForProjects;
var
  I, FailCount: Integer;
  P: TProject;
  SourceOpt: TSourceTextOption;
  SourceDir, Err, FailMsg: string;
begin
  UpdateStartupSplash(rsSplashCheckingSources);
  FailCount := 0;
  FailMsg := '';

  for I := 0 to Length(FProjects) - 1 do
  begin
    if FProjects[I].HasIssues then
      Continue;
    P := TProject.Create(FProjects[I].FullPath);
    try
      SourceOpt.SourceDir := '';
      SourceOpt.SourceLangCode := P.GetSourceLanguageCode;
      if SourceOpt.SourceLangCode = '' then
        SourceOpt.SourceLangCode := 'en';
      SourceOpt.SourceLangName := '';
      SourceOpt.BookCode := P.BookCode;
      SourceOpt.BookName := FProjects[I].BookName;
      SourceOpt.ResourceID := P.GetSourceResourceType;
      if SourceOpt.ResourceID = '' then
        SourceOpt.ResourceID := 'ulb';
      SourceOpt.ResourceName := '';

      if (SourceOpt.BookCode = '') then
        Continue;

      if not EnsureSourceTextPresent(SourceOpt, SourceDir, Err) then
      begin
        Inc(FailCount);
        if FailMsg = '' then
          FailMsg := FProjects[I].BookCode + ': ' + Err;
      end;
    finally
      P.Free;
    end;
  end;

  if FailCount > 0 then
    ShowMessage(Format(rsSomeSourcesCouldNotBePreparedFmt, [FailCount, FailMsg]));
end;

procedure TMainWindow.ScanAndDisplayProjects;
begin
  try
    UpdateStartupSplash(rsSplashScanningFolders);
    FProjects := ScanProjects;
    UpdateStartupSplash(rsSplashPreparingResources);
    EnsureSourcesForProjects;
    UpdateStartupSplash(rsSplashRenderingList);
    SortProjects;
    RefreshProjectListUI;

    if not FFirstLoadDone then
      FFirstLoadDone := True;
  finally
    HideStartupSplash;
  end;
end;

procedure TMainWindow.AsyncProjectRescan(Data: PtrInt);
begin
  LogInfo('AsyncProjectRescan fired');
  ScanAndDisplayProjects;
  LogInfo('AsyncProjectRescan complete');
end;

procedure TMainWindow.QueueProjectRescan;
begin
  Application.QueueAsyncCall(@AsyncProjectRescan, 0);
end;

procedure TMainWindow.SortProjects;
begin
  if Length(FProjects) <= 1 then
    Exit;
  QuickSortProjects(FProjects, 0, High(FProjects), cmbSortBy.ItemIndex,
    cmbSortColumnBy.ItemIndex);
end;

procedure TMainWindow.ClearProjectRows;
var
  C: TControl;
begin
  LogFmt(llInfo, 'ClearProjectRows: controlCount=%d', [ProjectScrollBox.ControlCount]);
  if (ProjectScrollBox = nil) or (csDestroying in ProjectScrollBox.ComponentState) then
    Exit;
  if (ProjectScrollBox.HandleAllocated = False) and (ProjectScrollBox.ControlCount = 0) then
    Exit;

  ProjectScrollBox.DisableAlign;
  ProjectScrollBox.DisableAutoSizing;
  try
    while ProjectScrollBox.ControlCount > 0 do
    begin
      C := ProjectScrollBox.Controls[ProjectScrollBox.ControlCount - 1];
      C.Parent := nil;
      C.Free;
    end;
  finally
    ProjectScrollBox.EnableAutoSizing;
    ProjectScrollBox.EnableAlign;
  end;
end;

procedure TMainWindow.CreateProjectRow(const S: TProjectSummary; Idx: Integer);
const
  ROW_HEIGHT = 68;
var
  RowPanel: TPanel;
  IssueMarker: TShape;
  lblName, lblType, lblLang: TLabel;
  pbPie: TPaintBox;
  btnInfo: TSpeedButton;
  TypeLabel: string;
  RowWidth: Integer;
  P: TThemePalette;
  AltBg: TColor;
begin
  P := GetThemePalette(GetEffectiveTheme);
  RowWidth := ProjectScrollBox.ClientWidth;

  { Alternate row: slightly shift the panel background }
  if (Idx mod 2) = 0 then
    AltBg := P.PanelBg
  else
  begin
    if GetEffectiveTheme = atDark then
      AltBg := P.SecondaryPanelBg
    else
      AltBg := $00FCFCFC;
  end;

  RowPanel := TPanel.Create(ProjectScrollBox);
  RowPanel.Parent := ProjectScrollBox;
  RowPanel.Height := ROW_HEIGHT;
  RowPanel.Align := alTop;
  RowPanel.Top := Idx * ROW_HEIGHT;
  RowPanel.BevelOuter := bvNone;
  RowPanel.ParentBackground := False;
  RowPanel.ParentColor := False;
  RowPanel.Tag := Idx;
  RowPanel.Cursor := crHandPoint;
  RowPanel.OnClick := @ProjectRowClick;
  RowPanel.Color := AltBg;

  { Issue marker — small red circle }
  IssueMarker := TShape.Create(RowPanel);
  IssueMarker.Parent := RowPanel;
  IssueMarker.Shape := stCircle;
  IssueMarker.SetBounds(8, 25, 10, 10);
  IssueMarker.Brush.Color := clRed;
  IssueMarker.Pen.Style := psClear;
  IssueMarker.Visible := S.HasIssues;

  { Project name }
  lblName := TLabel.Create(RowPanel);
  lblName.Parent := RowPanel;
  lblName.Left := 30;
  lblName.Top := 20;
  lblName.Font.Height := -19;
  lblName.Font.Style := [];
  lblName.Caption := ProjectDisplayName(S);
  lblName.OnClick := @ProjectRowClick;
  lblName.Cursor := crHandPoint;
  lblName.Tag := Idx;
  if S.HasIssues then
    lblName.Font.Color := clRed
  else
    lblName.Font.Color := P.TextPrimary;

  { Type label }
  lblType := TLabel.Create(RowPanel);
  lblType.Parent := RowPanel;
  lblType.Left := Round(RowWidth * 0.37);
  lblType.Top := 23;
  lblType.Font.Height := -15;
  lblType.Cursor := crHandPoint;
  lblType.OnClick := @ProjectRowClick;
  lblType.Tag := Idx;
  if Trim(S.ResourceType) = '' then
    TypeLabel := rsTypeUnknown
  else if LowerCase(Trim(S.ResourceType)) = 'tn' then
    TypeLabel := 'Notes'
  else if LowerCase(Trim(S.ResourceType)) = 'tq' then
    TypeLabel := 'Questions'
  else if LowerCase(Trim(S.ResourceType)) = 'tw' then
    TypeLabel := 'Words'
  else
    TypeLabel := rsTypeTextPrefix + S.ResourceType;
  lblType.Caption := TypeLabel;
  if S.HasIssues then
    lblType.Font.Color := clRed
  else
    lblType.Font.Color := P.TextSecondary;

  { Language label }
  lblLang := TLabel.Create(RowPanel);
  lblLang.Parent := RowPanel;
  lblLang.Left := Round(RowWidth * 0.53);
  lblLang.Top := 23;
  lblLang.Font.Height := -15;
  lblLang.Cursor := crHandPoint;
  lblLang.OnClick := @ProjectRowClick;
  lblLang.Tag := Idx;
  lblLang.Caption := S.TargetLangName;
  if S.HasIssues then
    lblLang.Font.Color := clRed
  else
    lblLang.Font.Color := P.TextSecondary;

  { Pie chart progress }
  pbPie := TPaintBox.Create(RowPanel);
  pbPie.Parent := RowPanel;
  pbPie.SetBounds(RowWidth - 140, (ROW_HEIGHT - 30) div 2, 30, 30);
  pbPie.Tag := ProjectProgressPct(S);
  pbPie.OnPaint := @PieChartPaint;
  pbPie.Cursor := crHandPoint;

  { Info button with circle background }
  with TShape.Create(RowPanel) do
  begin
    Parent := RowPanel;
    Shape := stCircle;
    SetBounds(RowWidth - 52, (ROW_HEIGHT - 24) div 2, 24, 24);
    Brush.Color := P.TextMuted;
    Pen.Style := psClear;
  end;
  btnInfo := TSpeedButton.Create(RowPanel);
  btnInfo.Parent := RowPanel;
  btnInfo.SetBounds(RowWidth - 52, (ROW_HEIGHT - 24) div 2, 24, 24);
  btnInfo.Caption := 'i';
  btnInfo.Flat := True;
  btnInfo.Font.Height := -14;
  btnInfo.Font.Color := P.TextInverse;
  btnInfo.Tag := Idx;
  btnInfo.OnClick := @InfoButtonClick;
  btnInfo.Hint := rsHintDetails;
  btnInfo.ShowHint := True;

  { Bottom separator line }
  with TShape.Create(RowPanel) do
  begin
    Parent := RowPanel;
    Shape := stRectangle;
    Align := alBottom;
    Height := 1;
    Pen.Style := psClear;
    Brush.Color := P.Border;
  end;
end;

procedure TMainWindow.RefreshProjectListUI;
var
  I, IssueCount: Integer;
begin
  if (ProjectScrollBox = nil) or (csDestroying in ProjectScrollBox.ComponentState) then
    Exit;

  IssueCount := 0;
  for I := 0 to Length(FProjects) - 1 do
    if FProjects[I].HasIssues then
      Inc(IssueCount);

  if Length(FProjects) = 0 then
  begin
    WelcomePanel.Visible := True;
    ProjectsTablePanel.Visible := False;
    lblProjectColumn.Visible := False;
    lblTypeColumn.Visible := False;
    lblLanguageColumn.Visible := False;
    lblProgressColumn.Visible := False;
    ProjectScrollBox.Visible := False;
    StatusBar.Panels[0].Text := rsNoProjectsFound;
  end
  else
  begin
    WelcomePanel.Visible := False;
    ProjectsTablePanel.Visible := True;
    lblProjectColumn.Visible := True;
    lblTypeColumn.Visible := True;
    lblLanguageColumn.Visible := True;
    lblProgressColumn.Visible := True;
    ProjectScrollBox.Visible := True;

    ClearProjectRows;
    ProjectScrollBox.DisableAutoSizing;
    try
      for I := 0 to Length(FProjects) - 1 do
        CreateProjectRow(FProjects[I], I);
    finally
      ProjectScrollBox.EnableAutoSizing;
    end;

    if IssueCount > 0 then
      StatusBar.Panels[0].Text := Format(rsProjectsFoundWithIssuesFmt,
        [Length(FProjects), IssueCount])
    else
      StatusBar.Panels[0].Text := Format(rsProjectsFoundFmt, [Length(FProjects)]);
  end;
end;

procedure TMainWindow.OpenProjectAtIndex(Idx: Integer);
var
  EditForm: TProjectEditWindow;
begin
  if (Idx < 0) or (Idx >= Length(FProjects)) then
    Exit;
  if FProjects[Idx].HasIssues then
  begin
    ShowMessage(rsProjectCannotOpenUntilIssuesFixedPrefix +
      FProjects[Idx].IssueSummary);
    Exit;
  end;

  LogFmt(llInfo, 'OpenProjectAtIndex(%d): creating EditForm', [Idx]);
  EditForm := TProjectEditWindow.Create(nil);
  try
    try
      EditForm.OpenProject(FProjects[Idx].FullPath, FProjects[Idx]);
      LogFmt(llInfo, 'OpenProjectAtIndex(%d): ShowModal', [Idx]);
      Hide;
      EditForm.ShowModal;
      LogFmt(llInfo, 'OpenProjectAtIndex(%d): ShowModal returned', [Idx]);
    except
      on E: Exception do
      begin
        LogFmt(llError, 'OpenProjectAtIndex(%d): exception: %s', [Idx, E.Message]);
        ShowMessage(rsProjectOpenSafelyAbortedPrefix + E.Message);
      end;
    end;
  finally
    LogFmt(llInfo, 'OpenProjectAtIndex(%d): FreeAndNil(EditForm)', [Idx]);
    FreeAndNil(EditForm);
    LogFmt(llInfo, 'OpenProjectAtIndex(%d): EditForm freed', [Idx]);
    Show;
  end;

  { Refresh project list after returning, deferred until current click stack unwinds }
  LogFmt(llInfo, 'OpenProjectAtIndex(%d): queueing rescan', [Idx]);
  QueueProjectRescan;
end;

procedure TMainWindow.ShowProjectDetails(Idx: Integer);
var
  D: TProjectDetailsWindow;
begin
  if (Idx < 0) or (Idx >= Length(FProjects)) then
    Exit;
  D := TProjectDetailsWindow.CreateDetails(nil, FProjects[Idx]);
  try
    D.ShowModal;
  finally
    D.Free;
  end;
  QueueProjectRescan;
end;

procedure TMainWindow.ProjectRowClick(Sender: TObject);
var
  Idx: Integer;
  Ctrl: TControl;
begin
  if Sender is TControl then
    Ctrl := TControl(Sender)
  else
    Exit;
  { Labels have their own Tag; panels have theirs }
  Idx := Ctrl.Tag;
  { If clicked a child label, its parent panel has the index too }
  if not (Ctrl is TPanel) and (Ctrl.Parent is TPanel) then
    Idx := Ctrl.Tag;
  LogFmt(llInfo, 'ProjectRowClick: idx=%d sender=%s — deferring open', [Idx, Ctrl.ClassName]);
  { Defer the modal open so this click handler returns first,
    letting the LCL finish mouse processing on the still-valid widget. }
  Application.QueueAsyncCall(@AsyncOpenProject, PtrInt(Idx));
end;

procedure TMainWindow.AsyncOpenProject(Data: PtrInt);
begin
  LogFmt(llInfo, 'AsyncOpenProject fired for idx=%d', [Integer(Data)]);
  OpenProjectAtIndex(Integer(Data));
  LogInfo('AsyncOpenProject complete');
end;

procedure TMainWindow.InfoButtonClick(Sender: TObject);
var
  Idx: Integer;
begin
  if Sender is TControl then
    Idx := TControl(Sender).Tag
  else
    Exit;
  ShowProjectDetails(Idx);
end;

procedure TMainWindow.PieChartPaint(Sender: TObject);
var
  PB: TPaintBox;
  Cvs: TCanvas;
  CX, CY, R: Integer;
  Pct: Integer;
  SweepAngle: Double;
  EndX, EndY: Integer;
  P: TThemePalette;
begin
  P := GetThemePalette(GetEffectiveTheme);
  PB := Sender as TPaintBox;
  Cvs := PB.Canvas;
  CX := PB.Width div 2;
  CY := PB.Height div 2;
  R := Min(CX, CY) - 1;
  Pct := PB.Tag;

  { Background circle }
  Cvs.Pen.Style := psClear;
  Cvs.Brush.Color := P.Border;
  Cvs.Ellipse(CX - R, CY - R, CX + R, CY + R);

  { Progress wedge — GTK2 draws counter-clockwise from start to end,
    so swap start/end to get clockwise fill from 12 o'clock }
  if Pct > 0 then
  begin
    if Pct >= 100 then
    begin
      Cvs.Brush.Color := P.Accent;
      Cvs.Ellipse(CX - R, CY - R, CX + R, CY + R);
    end
    else
    begin
      SweepAngle := 2 * Pi * (Pct / 100.0) - (Pi / 2);
      EndX := CX + Round(Cos(SweepAngle) * R);
      EndY := CY + Round(Sin(SweepAngle) * R);
      Cvs.Brush.Color := P.Accent;
      Cvs.Pie(CX - R, CY - R, CX + R, CY + R,
              EndX, EndY, CX, CY - R);
    end;
  end;
  Cvs.Pen.Style := psSolid;
end;

procedure TMainWindow.StartNewProjectFlow;
var
  TargetLangCode, TargetLangName: string;
  BookCode, BookName: string;
  SourceOpt: TSourceTextOption;
  ProjType: TProjectTypeID;
  NewProjectDir, Err: string;
begin
  if not PromptForTargetLanguage(TargetLangCode, TargetLangName) then
    Exit;

  if not PromptForBook(BookCode, BookName) then
    Exit;

  { Gateway Language Mode: show project type picker (Text/Notes/Questions) }
  ProjType := ptText;
  if GetGatewayLanguageMode then
  begin
    if not PromptForProjectType(Trim(TargetLangCode), Trim(BookCode), ProjType) then
      Exit;
  end;

  if not PromptForSourceText(Trim(BookCode), SourceOpt) then
    Exit;

  if not CreateProjectFromSource(Trim(TargetLangCode), Trim(TargetLangName),
    SourceOpt, ProjType, NewProjectDir, Err) then
  begin
    ShowMessage(Err);
    ScanAndDisplayProjects;
    Exit;
  end;

  ShowMessage(rsProjectCreatedPrefix + NewProjectDir);
  ScanAndDisplayProjects;
end;


procedure TMainWindow.StatusBarDrawPanel(AStatusBar: TStatusBar;
  Panel: TStatusPanel; const Rect: TRect);
var
  P: TThemePalette;
  TextY: Integer;
begin
  P := GetThemePalette(GetEffectiveTheme);
  AStatusBar.Canvas.Brush.Color := AStatusBar.Color;
  AStatusBar.Canvas.FillRect(Rect);
  AStatusBar.Canvas.Font.Assign(AStatusBar.Font);
  if GetEffectiveTheme = atLight then
    AStatusBar.Canvas.Font.Color := clWhite
  else
    AStatusBar.Canvas.Font.Color := P.HeaderText;
  TextY := Rect.Top + ((Rect.Bottom - Rect.Top - AStatusBar.Canvas.TextHeight(Panel.Text)) div 2);
  AStatusBar.Canvas.TextOut(Rect.Left + 8, TextY, Panel.Text);
end;

procedure TMainWindow.MenuUpdateClick(Sender: TObject);
begin
  ShowMessage(rsUpdateNotImplemented);
end;

procedure TMainWindow.MenuImportClick(Sender: TObject);
var
  Choice: TImportChoice;
begin
  Choice := ShowImportDialog(IsServerUser(FCurrentUser));
  case Choice of
    icProject: DoImportProjectFile;
    icServer: DoImportFromServer;
    icUSFM: DoImportUSFMFile;
    icSourceText: DoImportSourceText;
  end;
end;

procedure TMainWindow.MenuFeedbackClick(Sender: TObject);
begin
  ShowFeedbackDialog;
end;

procedure TMainWindow.UpdateDevToolsMenuItem;
var
  I: Integer;
  Item: TMenuItem;
  Found: Boolean;
begin
  { Check if dev tools item already exists }
  Found := False;
  for I := 0 to FMainMenu.Items.Count - 1 do
    if FMainMenu.Items[I].Caption = rsMenuDevTools then
    begin
      Found := True;
      if not GetDeveloperTools then
        FMainMenu.Items.Delete(I);
      Break;
    end;

  { Add if enabled and not found }
  if GetDeveloperTools and not Found then
  begin
    Item := TMenuItem.Create(FMainMenu);
    Item.Caption := rsMenuDevTools;
    Item.OnClick := @MenuDevToolsClick;
    FMainMenu.Items.Add(Item);
  end;
end;

procedure TMainWindow.MenuSettingsClick(Sender: TObject);
var
  OldTheme, NewTheme: TAppTheme;
  OldSuite, NewSuite: string;
begin
  if ShowSettingsDialog(OldTheme, NewTheme, OldSuite, NewSuite) then
  begin
    if NewTheme <> OldTheme then
      ApplyTheme;
    if NewSuite <> OldSuite then
    begin
      ShowMessage('Server suite changed to ' + UpperCase(NewSuite) +
        '. You will be logged out.');
      DoLogout;
      EnsureUserProfile;
    end;
  end;
  { Always update dev tools menu item after settings dialog }
  LogFmt(llInfo, 'After settings: developer_tools=%s', [BoolToStr(GetDeveloperTools, True)]);
  UpdateDevToolsMenuItem;
end;

procedure TMainWindow.MenuDevToolsClick(Sender: TObject);
begin
  ShowDevToolsWindow;
end;

procedure TMainWindow.ShowFeedbackDialog;
var
  F: TForm;
  lblTitle, lblWarning: TLabel;
  Memo: TMemo;
  btnSend, btnCancel: TButton;
  Pal: TThemePalette;
  FeedbackText: string;
begin
  Pal := GetThemePalette(GetEffectiveTheme);
  F := TForm.Create(nil);
  try
    F.Position := poScreenCenter;
    F.BorderStyle := bsSingle;
    F.Caption := rsFeedbackTitle;
    F.Font.Name := 'Noto Sans';
    F.Width := 460;
    F.Height := 340;
    F.Color := Pal.PanelBG;

    lblTitle := TLabel.Create(F);
    lblTitle.Parent := F;
    lblTitle.Left := 40;
    lblTitle.Top := 16;
    lblTitle.Font.Height := -16;
    lblTitle.Font.Style := [fsBold];
    lblTitle.Font.Color := Pal.TextPrimary;
    lblTitle.Caption := rsFeedbackTitle;

    lblWarning := TLabel.Create(F);
    lblWarning.Parent := F;
    lblWarning.Left := 40;
    lblWarning.Top := 42;
    lblWarning.Font.Height := -14;
    lblWarning.Font.Color := Pal.TextSecondary;
    lblWarning.Caption := rsFeedbackWarning;

    Memo := TMemo.Create(F);
    Memo.Parent := F;
    Memo.SetBounds(24, 70, 410, 190);
    Memo.Font.Height := -15;
    Memo.ScrollBars := ssAutoVertical;
    Memo.TextHint := rsFeedbackHint;

    btnCancel := TButton.Create(F);
    btnCancel.Parent := F;
    btnCancel.SetBounds(260, 274, 80, 32);
    btnCancel.Caption := rsFeedbackCancel;
    btnCancel.ModalResult := mrCancel;

    btnSend := TButton.Create(F);
    btnSend.Parent := F;
    btnSend.SetBounds(350, 274, 80, 32);
    btnSend.Caption := rsFeedbackSend;
    btnSend.ModalResult := mrOK;
    btnSend.Default := True;

    if F.ShowModal = mrOK then
    begin
      FeedbackText := Trim(Memo.Text);
      if FeedbackText = '' then
      begin
        ShowMessage(rsFeedbackEmpty);
        Exit;
      end;
      { TODO: Send feedback to server. For now, log it locally. }
      LogFmt(llInfo, 'User feedback: %s', [FeedbackText]);
      ShowMessage(rsFeedbackSent);
    end;
  finally
    F.Free;
  end;
end;

procedure TMainWindow.GlobalExceptionHandler(Sender: TObject; E: Exception);
var
  SenderName: string;
begin
  if Sender <> nil then
    SenderName := Sender.ClassName
  else
    SenderName := '<nil>';
  LogFmt(llError, 'UNHANDLED EXCEPTION sender=%s: %s: %s addr=%p',
    [SenderName, E.ClassName, E.Message, ExceptAddr]);
  ShowMessage('Unexpected error: ' + E.Message);
end;

procedure TMainWindow.EnsureUserProfile;
var
  Profile: TUserProfile;
begin
  FCurrentUser := LoadUserProfile;
  if (FCurrentUser.FullName = '') and (FCurrentUser.Username = '') then
  begin
    LogInfo('No user profile found — showing login dialog');
    HideStartupSplash;
    if ShowLoginDialog(Profile) then
    begin
      SaveUserProfile(Profile);
      FCurrentUser := Profile;
      LogFmt(llInfo, 'User profile set: %s (local=%s)',
        [FCurrentUser.FullName, BoolToStr(FCurrentUser.IsLocal, 'yes', 'no')]);
    end
    else
    begin
      LogInfo('Login dialog quit — terminating application');
      Application.Terminate;
      Exit;
    end;
    ShowStartupSplash;
  end
  else
    LogFmt(llInfo, 'Loaded user profile: %s (local=%s)',
      [FCurrentUser.FullName, BoolToStr(FCurrentUser.IsLocal, 'yes', 'no')]);
  UpdateUserDisplay;
end;

procedure TMainWindow.UpdateUserDisplay;
var
  DisplayName: string;
begin
  if FCurrentUser.FullName <> '' then
    DisplayName := FCurrentUser.FullName
  else if FCurrentUser.Username <> '' then
    DisplayName := FCurrentUser.Username
  else
    DisplayName := rsNoUser;

  lblCurrentUser.Caption := rsCurrentUserPrefix + DisplayName;
  btnLogout.Visible := (FCurrentUser.FullName <> '') or (FCurrentUser.Username <> '');
end;

procedure TMainWindow.DoLogout;
begin
  LogInfo('User logout requested');
  { Delete token from server if this is a server user }
  if IsServerUser(FCurrentUser) then
  begin
    try
      GiteaLogout(FCurrentUser.ServerURL, FCurrentUser.Username,
        FCurrentUser.Token, FCurrentUser.TokenID);
    except
      on E: Exception do
        LogFmt(llWarn, 'Token deletion during logout failed: %s', [E.Message]);
    end;
  end;
  ClearUserProfile;
  FCurrentUser := Default(TUserProfile);
  UpdateUserDisplay;
  LogInfo('User logged out');
end;

procedure TMainWindow.LogoutClick(Sender: TObject);
begin
  if MessageDlg(rsLogoutConfirm, mtConfirmation, [mbYes, mbNo], 0) = mrYes then
  begin
    DoLogout;
    { Show login dialog again }
    EnsureUserProfile;
  end;
end;

{ --- Import/Export implementations --- }

{ Extract .tstudio to a temp dir, read its canonical name, then move to
  the correct location.  Cleans up the outer manifest.json that unzip
  leaves in the dest root.  Returns the final canonical project dir. }
function ExtractTStudioToCanonical(const PackagePath, DestRoot: string;
  out FinalDir: string; out ErrorMsg: string): Boolean;
var
  TmpRoot, ExtractedDir, CanonName, CanonDir, OuterManifest: string;
  OutText, ErrText: string;
  ExitCode: Integer;
begin
  Result := False;
  FinalDir := '';

  { Extract to a temp sub-dir first so we can rename freely }
  TmpRoot := GetTempDir + 'bttw_ext_' + FormatDateTime('yyyymmddhhnnsszzz', Now);
  ForceDirectories(TmpRoot);

  if not ExtractTStudioPackage(PackagePath, TmpRoot, ExtractedDir, ErrorMsg) then
  begin
    RunCommandCapture('bash', ['-lc', 'rm -rf ' + ShellQuote(TmpRoot)],
      '', OutText, ErrText, ExitCode);
    Exit;
  end;

  if not FileExists(IncludeTrailingPathDelimiter(ExtractedDir) + 'manifest.json') then
  begin
    ErrorMsg := 'manifest.json not found in extracted project.';
    RunCommandCapture('bash', ['-lc', 'rm -rf ' + ShellQuote(TmpRoot)],
      '', OutText, ErrText, ExitCode);
    Exit;
  end;

  { Determine canonical dir name from the inner manifest }
  CanonName := ReadCanonicalDirName(ExtractedDir);
  if CanonName = '' then
    CanonName := ExtractFileName(ExcludeTrailingPathDelimiter(ExtractedDir));

  CanonDir := IncludeTrailingPathDelimiter(DestRoot) + CanonName;
  FinalDir := CanonDir;

  { Move extracted project to canonical location }
  if not DirectoryExists(DestRoot) then
    ForceDirectories(DestRoot);
  if DirectoryExists(CanonDir) then
  begin
    { Caller should have handled duplicate check already — remove stale }
    RunCommandCapture('bash', ['-lc', 'rm -rf ' + ShellQuote(CanonDir)],
      '', OutText, ErrText, ExitCode);
  end;
  MoveDirectorySafe(ExtractedDir, CanonDir);

  { Clean up temp dir (outer manifest.json and empty dirs) }
  RunCommandCapture('bash', ['-lc', 'rm -rf ' + ShellQuote(TmpRoot)],
    '', OutText, ErrText, ExitCode);

  { Also delete any outer manifest.json left in destRoot from prior bad imports }
  OuterManifest := IncludeTrailingPathDelimiter(DestRoot) + 'manifest.json';
  if FileExists(OuterManifest) then
    DeleteFile(OuterManifest);

  Result := True;
end;

procedure TMainWindow.DoImportProjectFile;
var
  OpenDlg: TOpenDialog;
  Info: TTStudioPackageInfo;
  ExtractedDir, Err, TargetDir, TempDir, CanonName: string;
  OutText, ErrText: string;
  ExitCode: Integer;
  Choice: TDuplicateChoice;
  HasConflicts: Boolean;
begin
  OpenDlg := TOpenDialog.Create(nil);
  try
    OpenDlg.Filter := rsImportTStudioFilter;
    OpenDlg.Title := 'Import Project File';
    if not OpenDlg.Execute then
      Exit;

    { Read package info to get project path }
    if not ReadTStudioPackageInfo(OpenDlg.FileName, Info, Err) then
    begin
      ShowMessage(rsImportFailedPrefix + Err);
      Exit;
    end;

    { Determine canonical target directory.  Extract to temp first to
      read the inner manifest (the outer one has only the original path). }
    TempDir := GetTempDir + 'bttw_peek_' + FormatDateTime('yyyymmddhhnnsszzz', Now);
    ForceDirectories(TempDir);
    if ExtractTStudioPackage(OpenDlg.FileName, TempDir, ExtractedDir, Err) then
      CanonName := ReadCanonicalDirName(ExtractedDir)
    else
      CanonName := '';
    RunCommandCapture('bash', ['-lc', 'rm -rf ' + ShellQuote(TempDir)],
      '', OutText, ErrText, ExitCode);
    if CanonName = '' then
      CanonName := Info.ProjectPath;

    TargetDir := IncludeTrailingPathDelimiter(GetTargetTranslationsPath) + CanonName;

    { Check for existing project }
    if DirectoryExists(TargetDir) then
    begin
      Choice := ShowDuplicateProjectDialog;
      case Choice of
        dcCancel: Exit;
        dcOverwrite:
        begin
          RunCommandCapture('bash', ['-lc', 'rm -rf ' + ShellQuote(TargetDir)],
            '', OutText, ErrText, ExitCode);
          if not ExtractTStudioToCanonical(OpenDlg.FileName,
            GetTargetTranslationsPath, ExtractedDir, Err) then
          begin
            ShowMessage(rsImportFailedPrefix + Err);
            Exit;
          end;
          EnsureProjectCommitted(ExtractedDir, Err);
          ShowMessage(rsImportSuccessPrefix +
            ExtractFileName(ExcludeTrailingPathDelimiter(ExtractedDir)));
          ScanAndDisplayProjects;
          Exit;
        end;
        dcMerge:
        begin
          { Extract to a temp directory, then merge into existing }
          TempDir := GetTempDir + 'bttw_import_' + FormatDateTime('yyyymmddhhnnss', Now);
          ForceDirectories(TempDir);
          if not ExtractTStudioToCanonical(OpenDlg.FileName, TempDir, ExtractedDir, Err) then
          begin
            ShowMessage(rsImportFailedPrefix + Err);
            RunCommandCapture('bash', ['-lc', 'rm -rf ' + ShellQuote(TempDir)],
              '', OutText, ErrText, ExitCode);
            Exit;
          end;
          EnsureProjectCommitted(ExtractedDir, Err);

          if not MergeImportedProject(TargetDir, ExtractedDir,
            HasConflicts, Err) then
          begin
            ShowMessage(rsImportFailedPrefix + Err);
            RunCommandCapture('bash', ['-lc', 'rm -rf ' + ShellQuote(TempDir)],
              '', OutText, ErrText, ExitCode);
            Exit;
          end;

          RunCommandCapture('bash', ['-lc', 'rm -rf ' + ShellQuote(TempDir)],
            '', OutText, ErrText, ExitCode);

          if HasConflicts then
            ShowMessage(rsImportMergedWithConflicts)
          else
            ShowMessage(rsImportSuccessPrefix +
              ExtractFileName(ExcludeTrailingPathDelimiter(TargetDir)));
          ScanAndDisplayProjects;
          Exit;
        end;
      end;
    end;

    { No existing project — extract to canonical location }
    if not ExtractTStudioToCanonical(OpenDlg.FileName,
      GetTargetTranslationsPath, ExtractedDir, Err) then
    begin
      ShowMessage(rsImportFailedPrefix + Err);
      Exit;
    end;

    EnsureProjectCommitted(ExtractedDir, Err);
    ShowMessage(rsImportSuccessPrefix +
      ExtractFileName(ExcludeTrailingPathDelimiter(ExtractedDir)));
    ScanAndDisplayProjects;
  finally
    OpenDlg.Free;
  end;
end;

procedure TMainWindow.DoExportUSFM(const ASummary: TProjectSummary);
var
  SaveDlg: TSaveDialog;
  Proj: TProject;
  SourceOpt: TSourceTextOption;
  SourceDir, Err: string;
begin
  { Resolve source content dir for chunk structure }
  Proj := TProject.Create(ASummary.FullPath);
  try
    SourceOpt.SourceLangCode := Proj.GetSourceLanguageCode;
    if SourceOpt.SourceLangCode = '' then
      SourceOpt.SourceLangCode := 'en';
    SourceOpt.BookCode := Proj.BookCode;
    SourceOpt.ResourceID := Proj.GetSourceResourceType;
    if SourceOpt.ResourceID = '' then
      SourceOpt.ResourceID := 'ulb';
  finally
    Proj.Free;
  end;

  SourceDir := GetLibraryPath + SourceOpt.SourceLangCode + '_' +
    SourceOpt.BookCode + '_' + SourceOpt.ResourceID +
    DirectorySeparator + 'content';
  if not DirectoryExists(SourceDir) then
  begin
    { Try to ensure source is present }
    SourceOpt.SourceDir := '';
    SourceOpt.SourceLangName := '';
    SourceOpt.BookName := ASummary.BookName;
    SourceOpt.ResourceName := '';
    if not EnsureSourceTextPresent(SourceOpt, SourceDir, Err) then
    begin
      ShowMessage(rsUSFMExportFailedPrefix + 'Source text not available: ' + Err);
      Exit;
    end;
    SourceDir := SourceDir + DirectorySeparator + 'content';
  end;

  SaveDlg := TSaveDialog.Create(nil);
  try
    SaveDlg.Filter := rsUSFMExportFilter;
    SaveDlg.DefaultExt := rsUSFMExt;
    { Canonical USFM filename: NN-CODE-lang.usfm (e.g. 41-MAT-icl.usfm) }
    SaveDlg.FileName := Format('%.2d-%s-%s.usfm',
      [USFMBookNumber(ASummary.BookCode),
       UpperCase(ASummary.BookCode),
       ASummary.TargetLangCode]);
    { Default to backup location }
    SaveDlg.InitialDir := GetBackupLocation;
    if (SaveDlg.InitialDir = '') or not DirectoryExists(SaveDlg.InitialDir) then
      SaveDlg.InitialDir := GetEnvironmentVariable('HOME');
    if not SaveDlg.Execute then
      Exit;

    if not ExportProjectToUSFM(ASummary.FullPath, SourceDir, SaveDlg.FileName, Err) then
    begin
      ShowMessage(rsUSFMExportFailedPrefix + Err);
      Exit;
    end;
    ShowMessage(rsUSFMExportedPrefix + SaveDlg.FileName);
  finally
    SaveDlg.Free;
  end;
end;

procedure TMainWindow.DoUploadToServer(const ASummary: TProjectSummary);
var
  RepoName, CloneURL, RemoteURL, Err, OutText, ErrText: string;
  ExitCode: Integer;
  ServerURL, Token, Username: string;
begin
  if not IsServerUser(FCurrentUser) then
  begin
    ShowMessage(rsUploadRequiresServer);
    Exit;
  end;

  ServerURL := FCurrentUser.ServerURL;
  if ServerURL = '' then
    ServerURL := DefaultDataServerURL;
  Token := FCurrentUser.Token;
  Username := FCurrentUser.Username;

  RepoName := ExtractFileName(ExcludeTrailingPathDelimiter(ASummary.FullPath));

  { Ensure all changes are committed }
  if not EnsureProjectCommitted(ASummary.FullPath, Err) then
  begin
    ShowMessage(rsUploadFailedPrefix + Err);
    Exit;
  end;

  { Create repo if it doesn't exist }
  if not GiteaRepoExists(ServerURL, Token, Username, RepoName) then
  begin
    if not GiteaCreateRepo(ServerURL, Token, RepoName, CloneURL, Err) then
    begin
      ShowMessage(rsUploadFailedPrefix + Err);
      Exit;
    end;
  end;

  { Build authenticated remote URL }
  RemoteURL := StringReplace(ServerURL, 'https://', 'https://' + Token + '@', []);
  RemoteURL := RemoteURL + '/' + Username + '/' + RepoName + '.git';

  { Set or update remote origin }
  RunCommandCapture('git', ['-C', ASummary.FullPath, 'remote', 'remove', 'origin'],
    '', OutText, ErrText, ExitCode);
  if not RunCommandCapture('git', ['-C', ASummary.FullPath, 'remote', 'add', 'origin', RemoteURL],
    '', OutText, ErrText, ExitCode) then
  begin
    ShowMessage(rsUploadFailedPrefix + 'Could not set remote: ' + ErrText);
    Exit;
  end;

  { Push }
  if not RunCommandCapture('git', ['-C', ASummary.FullPath, 'push', '-u', 'origin', 'master'],
    '', OutText, ErrText, ExitCode) then
  begin
    ShowMessage(rsUploadFailedPrefix + 'Push failed: ' + ErrText);
    Exit;
  end;
  if ExitCode <> 0 then
  begin
    ShowMessage(rsUploadFailedPrefix + Trim(ErrText));
    Exit;
  end;

  ShowMessage(rsUploadSuccessPrefix + Username + '/' + RepoName);
end;

{ Server import search dialog — searches on text change with a debounce timer }
type
  TServerImportForm = class(TForm)
  private
    FEdUser, FEdBook: TEdit;
    FGrid: TStringGrid;
    FBtnCancel, FBtnImport: TButton;
    FSearchTimer: TTimer;
    FRepos: TGiteaRepoArray;
    FServerURL, FToken: string;
    FSelectedIndex: Integer;
    procedure SearchTimerFire(Sender: TObject);
    procedure EditChanged(Sender: TObject);
    procedure GridDblClick(Sender: TObject);
    procedure GridSelection(Sender: TObject; aCol, aRow: Integer);
    procedure ImportBtnClick(Sender: TObject);
    procedure DoSearch;
  end;

procedure TServerImportForm.EditChanged(Sender: TObject);
begin
  { Restart debounce timer on each keystroke }
  FSearchTimer.Enabled := False;
  FSearchTimer.Enabled := True;
end;

procedure TServerImportForm.SearchTimerFire(Sender: TObject);
begin
  FSearchTimer.Enabled := False;
  DoSearch;
end;

procedure TServerImportForm.DoSearch;
var
  UserQuery, BookQuery, Err: string;
  AllRepos: TGiteaRepoArray;
  I, Count: Integer;
  BookLower: string;
begin
  UserQuery := Trim(FEdUser.Text);
  BookQuery := Trim(FEdBook.Text);

  if (UserQuery = '') and (BookQuery = '') then
  begin
    FGrid.RowCount := 1;
    SetLength(FRepos, 0);
    Exit;
  end;

  if UserQuery <> '' then
  begin
    { List repos for the specific user }
    if not GiteaListUserRepos(FServerURL, FToken, UserQuery, 50, AllRepos, Err) then
    begin
      FGrid.RowCount := 1;
      SetLength(FRepos, 0);
      Exit;
    end;
    { If book/language filter provided, filter client-side }
    if BookQuery <> '' then
    begin
      BookLower := LowerCase(BookQuery);
      SetLength(FRepos, 0);
      for I := 0 to Length(AllRepos) - 1 do
      begin
        if Pos(BookLower, LowerCase(AllRepos[I].Name)) > 0 then
        begin
          SetLength(FRepos, Length(FRepos) + 1);
          FRepos[Length(FRepos) - 1] := AllRepos[I];
        end;
      end;
    end
    else
      FRepos := AllRepos;
  end
  else
  begin
    { No username — search by book/language via general search }
    if not GiteaSearchRepos(FServerURL, FToken, BookQuery, 50, FRepos, Err) then
    begin
      FGrid.RowCount := 1;
      SetLength(FRepos, 0);
      Exit;
    end;
  end;

  FGrid.RowCount := 1 + Length(FRepos);
  for I := 0 to Length(FRepos) - 1 do
  begin
    FGrid.Cells[0, I + 1] := FRepos[I].Owner;
    FGrid.Cells[1, I + 1] := FRepos[I].Name;
  end;
  FSelectedIndex := -1;
end;

procedure TServerImportForm.GridDblClick(Sender: TObject);
begin
  if (FGrid.Row >= 1) and (FGrid.Row <= Length(FRepos)) then
  begin
    FSelectedIndex := FGrid.Row - 1;
    ModalResult := mrOK;
  end;
end;

procedure TServerImportForm.GridSelection(Sender: TObject; aCol, aRow: Integer);
begin
  if (aRow >= 1) and (aRow <= Length(FRepos)) then
    FSelectedIndex := aRow - 1
  else
    FSelectedIndex := -1;
end;

procedure TServerImportForm.ImportBtnClick(Sender: TObject);
begin
  if (FSelectedIndex >= 0) and (FSelectedIndex < Length(FRepos)) then
    ModalResult := mrOK;
end;

procedure TMainWindow.DoImportFromServer;
var
  Err, TargetDir, RemoteURL, OutText, ErrText: string;
  TempDir, TempCloneDir, CanonName: string;
  ExitCode: Integer;
  ServerURL, Token: string;
  F: TServerImportForm;
  Pal: TThemePalette;
  SearchPanel, BtnPanel: TPanel;
  lblTitle: TLabel;
  Sep1, Sep2: TBevel;
  SelectedRepo: TGiteaRepoInfo;
  Choice: TDuplicateChoice;
  HasConflicts: Boolean;
begin
  if not IsServerUser(FCurrentUser) then
  begin
    ShowMessage(rsUploadRequiresServer);
    Exit;
  end;

  ServerURL := FCurrentUser.ServerURL;
  if ServerURL = '' then
    ServerURL := DefaultDataServerURL;
  Token := FCurrentUser.Token;

  Pal := GetThemePalette(GetEffectiveTheme);
  F := TServerImportForm.CreateNew(nil);
  try
    F.FServerURL := ServerURL;
    F.FToken := Token;
    F.FSelectedIndex := -1;
    F.Position := poScreenCenter;
    F.BorderStyle := bsSingle;
    F.Caption := rsServerSearchTitle;
    F.Font.Name := 'Noto Sans';
    F.Width := 500;
    F.Height := 520;
    F.Color := Pal.PanelBg;

    { Title }
    lblTitle := TLabel.Create(F);
    lblTitle.Parent := F;
    lblTitle.Align := alTop;
    lblTitle.Height := 40;
    lblTitle.Alignment := taCenter;
    lblTitle.Layout := tlCenter;
    lblTitle.Caption := rsServerSearchTitle;
    lblTitle.Font.Height := -18;
    lblTitle.Font.Style := [fsBold];
    lblTitle.Font.Color := Pal.TextPrimary;

    { Search fields panel }
    SearchPanel := TPanel.Create(F);
    SearchPanel.Parent := F;
    SearchPanel.Align := alTop;
    SearchPanel.Height := 40;
    SearchPanel.BevelOuter := bvNone;
    SearchPanel.Color := Pal.PanelBg;

    F.FEdUser := TEdit.Create(F);
    F.FEdUser.Parent := SearchPanel;
    F.FEdUser.SetBounds(24, 6, 200, 28);
    F.FEdUser.TextHint := 'User Name';
    F.FEdUser.Font.Height := -15;
    F.FEdUser.OnChange := @F.EditChanged;

    F.FEdBook := TEdit.Create(F);
    F.FEdBook.Parent := SearchPanel;
    F.FEdBook.SetBounds(240, 6, 220, 28);
    F.FEdBook.TextHint := 'Book or Language';
    F.FEdBook.Font.Height := -15;
    F.FEdBook.OnChange := @F.EditChanged;

    { Separator }
    Sep1 := TBevel.Create(F);
    Sep1.Parent := F;
    Sep1.Align := alTop;
    Sep1.Height := 2;
    Sep1.Shape := bsTopLine;

    { Results grid }
    F.FGrid := TStringGrid.Create(F);
    F.FGrid.Parent := F;
    F.FGrid.Align := alClient;
    F.FGrid.FixedRows := 1;
    F.FGrid.FixedCols := 0;
    F.FGrid.RowCount := 1;
    F.FGrid.ColCount := 2;
    F.FGrid.ColWidths[0] := 150;
    F.FGrid.ColWidths[1] := 300;
    F.FGrid.Cells[0, 0] := 'User Name';
    F.FGrid.Cells[1, 0] := 'Project Name';
    F.FGrid.Options := F.FGrid.Options + [goRowSelect] - [goEditing, goRangeSelect];
    F.FGrid.Font.Height := -14;
    F.FGrid.Color := Pal.MemoBg;
    F.FGrid.FixedColor := Pal.PrimaryLight;
    F.FGrid.OnDblClick := @F.GridDblClick;
    F.FGrid.OnSelection := @F.GridSelection;

    { Bottom separator + cancel }
    Sep2 := TBevel.Create(F);
    Sep2.Parent := F;
    Sep2.Align := alBottom;
    Sep2.Height := 2;
    Sep2.Shape := bsBottomLine;

    BtnPanel := TPanel.Create(F);
    BtnPanel.Parent := F;
    BtnPanel.Align := alBottom;
    BtnPanel.Height := 44;
    BtnPanel.BevelOuter := bvNone;
    BtnPanel.Color := Pal.PanelBg;

    F.FBtnImport := TButton.Create(F);
    F.FBtnImport.Parent := BtnPanel;
    F.FBtnImport.SetBounds(280, 8, 90, 30);
    F.FBtnImport.Caption := 'Import';
    F.FBtnImport.Font.Height := -13;
    F.FBtnImport.OnClick := @F.ImportBtnClick;

    F.FBtnCancel := TButton.Create(F);
    F.FBtnCancel.Parent := BtnPanel;
    F.FBtnCancel.SetBounds(380, 8, 90, 30);
    F.FBtnCancel.Caption := 'CANCEL';
    F.FBtnCancel.Font.Height := -13;
    F.FBtnCancel.ModalResult := mrCancel;

    { Debounce timer }
    F.FSearchTimer := TTimer.Create(F);
    F.FSearchTimer.Interval := 400;
    F.FSearchTimer.Enabled := False;
    F.FSearchTimer.OnTimer := @F.SearchTimerFire;

    if F.ShowModal <> mrOK then
      Exit;

    if (F.FSelectedIndex < 0) or (F.FSelectedIndex >= Length(F.FRepos)) then
      Exit;

    SelectedRepo := F.FRepos[F.FSelectedIndex];
  finally
    F.Free;
  end;

  { Build authenticated clone URL }
  RemoteURL := StringReplace(SelectedRepo.CloneURL,
    'https://', 'https://' + Token + '@', []);

  { Clone to a temp dir first to determine canonical name }
  TempDir := GetTempDir + 'bttw_server_' + FormatDateTime('yyyymmddhhnnsszzz', Now);
  ForceDirectories(TempDir);
  TempCloneDir := IncludeTrailingPathDelimiter(TempDir) + SelectedRepo.Name;
  if not RunCommandCapture('git', ['clone', RemoteURL, TempCloneDir],
    '', OutText, ErrText, ExitCode) then
  begin
    ShowMessage(rsImportFailedPrefix + 'Clone failed: ' + ErrText);
    RunCommandCapture('bash', ['-lc', 'rm -rf ' + ShellQuote(TempDir)],
      '', OutText, ErrText, ExitCode);
    Exit;
  end;
  if ExitCode <> 0 then
  begin
    ShowMessage(rsImportFailedPrefix + Trim(ErrText));
    RunCommandCapture('bash', ['-lc', 'rm -rf ' + ShellQuote(TempDir)],
      '', OutText, ErrText, ExitCode);
    Exit;
  end;

  if not FileExists(IncludeTrailingPathDelimiter(TempCloneDir) + 'manifest.json') then
  begin
    ShowMessage(rsImportFailedPrefix + 'Repository does not contain a valid BTT-Writer project.');
    RunCommandCapture('bash', ['-lc', 'rm -rf ' + ShellQuote(TempDir)],
      '', OutText, ErrText, ExitCode);
    Exit;
  end;

  { Determine canonical dir name }
  CanonName := ReadCanonicalDirName(TempCloneDir);
  if CanonName = '' then
    CanonName := SelectedRepo.Name;
  TargetDir := IncludeTrailingPathDelimiter(GetTargetTranslationsPath) + CanonName;

  if DirectoryExists(TargetDir) then
  begin
    Choice := ShowDuplicateProjectDialog;
    case Choice of
      dcCancel:
      begin
        RunCommandCapture('bash', ['-lc', 'rm -rf ' + ShellQuote(TempDir)],
          '', OutText, ErrText, ExitCode);
        Exit;
      end;
      dcOverwrite:
      begin
        RunCommandCapture('bash', ['-lc', 'rm -rf ' + ShellQuote(TargetDir)],
          '', OutText, ErrText, ExitCode);
        { Move clone to canonical location }
        MoveDirectorySafe(TempCloneDir, TargetDir);
        RunCommandCapture('rm', ['-rf', TempDir], '', OutText, ErrText, ExitCode);
        ShowMessage(rsImportSuccessPrefix + CanonName);
        ScanAndDisplayProjects;
        Exit;
      end;
      dcMerge:
      begin
        if not MergeImportedProject(TargetDir, TempCloneDir,
          HasConflicts, Err) then
        begin
          ShowMessage(rsImportFailedPrefix + Err);
          RunCommandCapture('bash', ['-lc', 'rm -rf ' + ShellQuote(TempDir)],
            '', OutText, ErrText, ExitCode);
          Exit;
        end;
        RunCommandCapture('bash', ['-lc', 'rm -rf ' + ShellQuote(TempDir)],
          '', OutText, ErrText, ExitCode);
        if HasConflicts then
          ShowMessage(rsImportMergedWithConflicts)
        else
          ShowMessage(rsImportSuccessPrefix + CanonName);
        ScanAndDisplayProjects;
        Exit;
      end;
    end;
  end;

  { No existing project — move clone to canonical location }
  ForceDirectories(GetTargetTranslationsPath);
  if not MoveDirectorySafe(TempCloneDir, TargetDir) then
  begin
    ShowMessage(rsImportFailedPrefix + 'Could not move project to ' + TargetDir);
    RunCommandCapture('rm', ['-rf', TempDir], '', OutText, ErrText, ExitCode);
    Exit;
  end;
  RunCommandCapture('rm', ['-rf', TempDir], '', OutText, ErrText, ExitCode);
  ShowMessage(rsImportSuccessPrefix + CanonName);
  ScanAndDisplayProjects;
end;

{ Write parsed USFM verses into chunk files grouped by English ULB toc
  boundaries. Falls back to per-verse files if no English ULB is available. }
procedure WriteUSFMVersesToChunks(const ParseResult: TUSFMParseResult;
  const ProjectDir, EnglishULBContentDir: string);
var
  ULBBook: TBook;
  ULBChapter: TChapter;
  I, J, ChapterNum, VerseNum, ChunkStart, NextChunkStart: Integer;
  ChDir, ChunkPath, ChunkContent: string;
  ChapterStr: string;
  SL: TStringList;
begin
  ULBBook := nil;
  if EnglishULBContentDir <> '' then
  begin
    ULBBook := TBook.Create('', 'ulb');
    ULBBook.LoadFromToc(EnglishULBContentDir);
  end;
  try
    for I := 0 to Length(ParseResult.Verses) - 1 do
    begin
      ChapterNum := ParseResult.Verses[I].Chapter;
      VerseNum := ParseResult.Verses[I].Verse;
      if ChapterNum <= 0 then
        Continue;

      ChapterStr := Format('%.2d', [ChapterNum]);
      ChDir := IncludeTrailingPathDelimiter(ProjectDir) + ChapterStr;
      ForceDirectories(ChDir);

      { Find which chunk this verse belongs to using the English ULB toc }
      ChunkStart := VerseNum;  { default: per-verse file }
      if ULBBook <> nil then
      begin
        ULBChapter := ULBBook.GetChapter(ChapterStr);
        if ULBChapter <> nil then
        begin
          { Walk the chunk list to find which chunk owns this verse.
            Each chunk name is the starting verse; a verse belongs to
            the chunk whose start is <= verse and whose next chunk start is > verse. }
          ChunkStart := VerseNum;
          for J := 0 to ULBChapter.Chunks.Count - 1 do
          begin
            if not TryStrToInt(ULBChapter.Chunks[J].Name, ChunkStart) then
              Continue;
            if J < ULBChapter.Chunks.Count - 1 then
            begin
              if TryStrToInt(ULBChapter.Chunks[J + 1].Name, NextChunkStart) then
              begin
                if (VerseNum >= ChunkStart) and (VerseNum < NextChunkStart) then
                  Break;
              end;
            end
            else
            begin
              { Last chunk — all remaining verses belong here }
              if VerseNum >= ChunkStart then
                Break;
            end;
          end;
        end;
      end;

      ChunkPath := IncludeTrailingPathDelimiter(ChDir) +
        Format('%.2d', [ChunkStart]) + '.txt';
      ChunkContent := ParseResult.Verses[I].Content;

      SL := TStringList.Create;
      try
        if FileExists(ChunkPath) then
          SL.LoadFromFile(ChunkPath);
        if Trim(SL.Text) = '' then
          SL.Text := ChunkContent
        else
          SL.Text := SL.Text + ChunkContent;
        SL.SaveToFile(ChunkPath);
      finally
        SL.Free;
      end;
    end;
  finally
    FreeAndNil(ULBBook);
  end;
end;

procedure TMainWindow.DoImportUSFMFile;
var
  OpenDlg: TOpenDialog;
  ParseResult: TUSFMParseResult;
  Err, BookCode: string;
  TargetLangCode, TargetLangName: string;
  SourceOpt: TSourceTextOption;
  ProjType: TProjectTypeID;
  NewProjectDir, SourceDir: string;
  ExistingDir, TempDir, TempProjDir, OutText, ErrText: string;
  ExitCode: Integer;
  Choice: TDuplicateChoice;
  HasConflicts: Boolean;
begin
  OpenDlg := TOpenDialog.Create(nil);
  try
    OpenDlg.Filter := rsUSFMImportFilter;
    OpenDlg.Title := 'Import USFM File';
    if not OpenDlg.Execute then
      Exit;

    if not ParseUSFMFile(OpenDlg.FileName, ParseResult, Err) then
    begin
      ShowMessage(rsImportFailedPrefix + Err);
      Exit;
    end;

    BookCode := LowerCase(Trim(ParseResult.BookID));
    if not IsCanonicalBibleBookCode(BookCode) then
    begin
      ShowMessage(rsImportFailedPrefix + 'Unrecognized book code: ' + ParseResult.BookID);
      Exit;
    end;

    { Prompt for target language }
    if not PromptForTargetLanguage(TargetLangCode, TargetLangName) then
      Exit;

    { Prompt for source text }
    ProjType := ptText;
    if not PromptForSourceText(BookCode, SourceOpt) then
      Exit;

    { Check for existing project — ptText produces «lang»_«book»_text_reg }
    ExistingDir := IncludeTrailingPathDelimiter(GetTargetTranslationsPath) +
      Trim(TargetLangCode) + '_' + SourceOpt.BookCode + '_text_reg';
    if DirectoryExists(ExistingDir) then
    begin
      Choice := ShowDuplicateProjectDialog;
      case Choice of
        dcCancel: Exit;
        dcOverwrite:
        begin
          RunCommandCapture('bash', ['-lc', 'rm -rf ' + ShellQuote(ExistingDir)],
            '', OutText, ErrText, ExitCode);
        end;
        dcMerge:
        begin
          { Create a temp project with the USFM content, then merge into existing }
          TempDir := GetTempDir + 'bttw_usfm_' + FormatDateTime('yyyymmddhhnnss', Now);
          ForceDirectories(TempDir);
          TempProjDir := IncludeTrailingPathDelimiter(TempDir) +
            Trim(TargetLangCode) + '_' + SourceOpt.BookCode + '_text_reg';
          ForceDirectories(TempProjDir);

          { Initialize git in temp so we can merge }
          RunCommandCapture('git', ['-C', TempProjDir, 'init'],
            '', OutText, ErrText, ExitCode);

          { Write USFM content to temp project }
          SourceDir := FindEnglishULBContentDir(BookCode);
          WriteUSFMVersesToChunks(ParseResult, TempProjDir, SourceDir);
          EnsureProjectCommitted(TempProjDir, Err);

          if not MergeImportedProject(ExistingDir, TempProjDir,
            HasConflicts, Err) then
          begin
            ShowMessage(rsImportFailedPrefix + Err);
            RunCommandCapture('bash', ['-lc', 'rm -rf ' + ShellQuote(TempDir)],
              '', OutText, ErrText, ExitCode);
            Exit;
          end;

          RunCommandCapture('bash', ['-lc', 'rm -rf ' + ShellQuote(TempDir)],
            '', OutText, ErrText, ExitCode);

          if HasConflicts then
            ShowMessage(rsImportMergedWithConflicts)
          else
            ShowMessage(rsImportSuccessPrefix +
              ExtractFileName(ExcludeTrailingPathDelimiter(ExistingDir)));
          ScanAndDisplayProjects;
          Exit;
        end;
      end;
    end;

    { Create the project structure (new or after overwrite) }
    if not CreateProjectFromSource(Trim(TargetLangCode), Trim(TargetLangName),
      SourceOpt, ProjType, NewProjectDir, Err) then
    begin
      ShowMessage(rsImportFailedPrefix + Err);
      Exit;
    end;

    { Write parsed verses into chunk files grouped by English ULB boundaries. }
    SourceDir := FindEnglishULBContentDir(BookCode);
    WriteUSFMVersesToChunks(ParseResult, NewProjectDir, SourceDir);

    { Commit the imported content }
    CommitProjectChanges(NewProjectDir, 'Import from USFM', Err);

    ShowMessage(rsImportSuccessPrefix + ExtractFileName(ExcludeTrailingPathDelimiter(NewProjectDir)));
    ScanAndDisplayProjects;
  finally
    OpenDlg.Free;
  end;
end;

procedure TMainWindow.DoImportSourceText;
var
  DirDlg: TSelectDirectoryDialog;
  PkgPath, TocPath, DestDir, DirName: string;
  SL: TStringList;
  Data: TJSONData;
  Obj: TJSONObject;
  Slug: string;
  OutText, ErrText: string;
  ExitCode: Integer;
begin
  DirDlg := TSelectDirectoryDialog.Create(nil);
  try
    DirDlg.Title := rsSourceImportTitle;
    if not DirDlg.Execute then
      Exit;

    DirName := DirDlg.FileName;
    PkgPath := IncludeTrailingPathDelimiter(DirName) + 'package.json';
    TocPath := IncludeTrailingPathDelimiter(DirName) + 'content' +
      DirectorySeparator + 'toc.yml';

    if (not FileExists(PkgPath)) or (not FileExists(TocPath)) then
    begin
      ShowMessage(rsSourceImportInvalidDir);
      Exit;
    end;

    { Read package.json for canonical slug }
    SL := TStringList.Create;
    try
      SL.LoadFromFile(PkgPath);
      Data := GetJSON(SL.Text);
      try
        if Data is TJSONObject then
        begin
          Obj := TJSONObject(Data);
          Slug := Obj.Get('name', '');
          if Slug = '' then
            Slug := ExtractFileName(ExcludeTrailingPathDelimiter(DirName));
        end
        else
          Slug := ExtractFileName(ExcludeTrailingPathDelimiter(DirName));
      finally
        Data.Free;
      end;
    finally
      SL.Free;
    end;

    DestDir := GetLibraryPath + Slug;
    ForceDirectories(GetLibraryPath);

    { Copy directory to library }
    if not RunCommandCapture('bash',
      ['-lc', 'cp -a ' + ShellQuote(ExcludeTrailingPathDelimiter(DirName)) + ' ' +
       ShellQuote(DestDir)],
      '', OutText, ErrText, ExitCode) then
    begin
      ShowMessage(rsSourceImportFailed + ErrText);
      Exit;
    end;
    if ExitCode <> 0 then
    begin
      ShowMessage(rsSourceImportFailed + Trim(ErrText));
      Exit;
    end;

    ShowMessage(rsSourceImportSuccess + Slug);
  finally
    DirDlg.Free;
  end;
end;

end.
