unit MainForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, Math,
  ExtCtrls, StdCtrls, Buttons, ComCtrls, LCLType,
  fpjson, jsonparser,
  Globals, ProjectScanner, ProjectEditForm, ProjectCreator, ProjectManager,
  TStudioPackage, SplashScreen, AppSettings, SettingsForm, ThemePalette, UIFonts;

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
  rsCurrentUserRaphael = 'Current User: Raphael';
  rsLogout = '(Logout)';
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
    ProjectListBox: TListBox;
    FProjects: TProjectSummaryList;
    FFirstLoadDone: Boolean;
    procedure UpdateLayout;
    procedure EnsureSourcesForProjects;
    procedure ScanAndDisplayProjects;
    procedure RefreshProjectListUI;
    procedure SortProjects;
    procedure SortComboChange(Sender: TObject);
    procedure ApplyTheme;
    procedure OpenProjectAtIndex(Idx: Integer);
    function IsInfoIconHit(Index, X, Y: Integer): Boolean;
    procedure ShowProjectDetails(Idx: Integer);
    procedure ProjectListBoxClick(Sender: TObject);
    procedure ProjectListBoxMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure ProjectListBoxMouseMove(Sender: TObject; Shift: TShiftState;
      X, Y: Integer);
    procedure StatusBarDrawPanel(AStatusBar: TStatusBar; Panel: TStatusPanel;
      const Rect: TRect);
    procedure ProjectListBoxDrawItem(Control: TWinControl; Index: Integer;
      ARect: TRect; State: TOwnerDrawState);
    procedure StartNewProjectFlow;
  public
  end;

var
  MainWindow: TMainWindow;

implementation

{$R *.lfm}

type
  TProjectDetailsWindow = class(TForm)
  private
    FSummary: TProjectSummary;
    lblTitle: TLabel;
    lblInfo: TLabel;
    memTranslators: TMemo;
    btnDismiss: TButton;
    btnExport: TButton;
    function LoadTranslatorsText: string;
    procedure btnDismissClick(Sender: TObject);
    procedure btnExportClick(Sender: TObject);
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

function CanonicalBookIndex(const BookCode: string): Integer;
const
  BOOK_ORDER: array[0..65] of string = (
    'gen','exo','lev','num','deu','jos','jdg','rut','1sa','2sa','1ki','2ki',
    '1ch','2ch','ezr','neh','est','job','psa','pro','ecc','sng','isa','jer',
    'lam','ezk','dan','hos','jol','amo','oba','jon','mic','nam','hab','zep',
    'hag','zec','mal','mat','mrk','luk','jhn','act','rom','1co','2co','gal',
    'eph','php','col','1th','2th','1ti','2ti','tit','phm','heb','jas','1pe',
    '2pe','1jn','2jn','3jn','jud','rev'
  );
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
begin
  inherited Create(AOwner);
  FSummary := ASummary;
  Position := poScreenCenter;
  Width := 520;
  Height := 430;
  BorderIcons := [biSystemMenu];
  Caption := rsProjectDetailsTitle;
  Color := clWhite;

  lblTitle := TLabel.Create(Self);
  lblTitle.Parent := Self;
  lblTitle.Left := 24;
  lblTitle.Top := 20;
  lblTitle.Font.Style := [fsBold];
  lblTitle.Font.Height := -24;
  lblTitle.Caption := FSummary.BookName + ' - ' + FSummary.TargetLangName;

  lblInfo := TLabel.Create(Self);
  lblInfo.Parent := Self;
  lblInfo.Left := 24;
  lblInfo.Top := 68;
  lblInfo.Font.Height := -16;
  if FSummary.TotalChunks > 0 then
    ProgressPct := (FSummary.FinishedChunks * 100) div FSummary.TotalChunks
  else
    ProgressPct := 0;
  lblInfo.Caption :=
    rsProjectLabel + FSummary.DirName + LineEnding +
    rsTargetLanguageLabel + FSummary.TargetLangCode + ' - ' + FSummary.TargetLangName + LineEnding +
    rsResourceTypeLabel + FSummary.ResourceType + LineEnding +
    rsProgressLabel + IntToStr(ProgressPct) + '%' + LineEnding +
    rsIssuesLabel + LineEnding +
    rsTranslatorsLabel;
  if FSummary.HasIssues then
    lblInfo.Caption := StringReplace(lblInfo.Caption, rsIssuesLabel + LineEnding,
      rsIssuesLabel + FSummary.IssueSummary + LineEnding, [])
  else
    lblInfo.Caption := StringReplace(lblInfo.Caption, rsIssuesLabel + LineEnding,
      rsIssuesLabel + rsIssuesNone + LineEnding, []);

  memTranslators := TMemo.Create(Self);
  memTranslators.Parent := Self;
  memTranslators.Left := 24;
  memTranslators.Top := 182;
  memTranslators.Width := 464;
  memTranslators.Height := 164;
  memTranslators.ReadOnly := True;
  memTranslators.ScrollBars := ssVertical;
  memTranslators.Lines.Text := LoadTranslatorsText;

  btnDismiss := TButton.Create(Self);
  btnDismiss.Parent := Self;
  btnDismiss.Left := 212;
  btnDismiss.Top := 360;
  btnDismiss.Width := 96;
  btnDismiss.Caption := rsDismiss;
  btnDismiss.OnClick := @btnDismissClick;

  btnExport := TButton.Create(Self);
  btnExport.Parent := Self;
  btnExport.Left := 384;
  btnExport.Top := 360;
  btnExport.Width := 104;
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

procedure TProjectDetailsWindow.btnDismissClick(Sender: TObject);
begin
  Close;
end;

procedure TProjectDetailsWindow.btnExportClick(Sender: TObject);
var
  SaveDlg: TSaveDialog;
  Err: string;
begin
  SaveDlg := TSaveDialog.Create(Self);
  try
    SaveDlg.Filter := rsExportFilter;
    SaveDlg.DefaultExt := rsTStudioExt;
    SaveDlg.FileName := FSummary.DirName + '.tstudio';
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
  InitializeAppSettings;
  FFirstLoadDone := False;
  ApplyFontRecursive(Self, 'Noto Sans');
  UpdateStartupSplash(rsSplashBuildingHome);
  Caption := APP_NAME + ' ' + APP_VERSION;
  lblCurrentUser.Caption := rsCurrentUserRaphael;
  btnLogout.Caption := rsLogout;

  { Create project list box }
  ProjectListBox := TListBox.Create(Self);
  ProjectListBox.Parent := ProjectsTablePanel;
  ProjectListBox.Left := 0;
  ProjectListBox.Top := 30;
  ProjectListBox.Width := ProjectsTablePanel.Width;
  ProjectListBox.Height := ProjectsTablePanel.Height - 30;
  ProjectListBox.Anchors := [akTop, akLeft, akRight, akBottom];
  ProjectListBox.Style := lbOwnerDrawFixed;
  ProjectListBox.ItemHeight := 62;
  ProjectListBox.OnMouseDown := @ProjectListBoxMouseDown;
  ProjectListBox.OnMouseMove := @ProjectListBoxMouseMove;
  ProjectListBox.OnDrawItem := @ProjectListBoxDrawItem;
  ProjectListBox.BorderStyle := bsNone;
  ProjectListBox.Color := clWhite;
  ProjectListBox.ShowHint := True;
  ProjectListBox.Visible := False;
  if StatusBar.Panels.Count > 0 then
    StatusBar.Panels[0].Style := psOwnerDraw;
  StatusBar.OnDrawPanel := @StatusBarDrawPanel;
  btnMenu.OnClick := @btnMenuClick;
  btnAddProject.OnClick := @btnAddProjectClick;
  btnStartProject.OnClick := @btnStartProjectClick;
  cmbSortBy.OnChange := @SortComboChange;
  cmbSortColumnBy.OnChange := @SortComboChange;

  ApplyTheme;
  UpdateStartupSplash(rsSplashLoadingProjects);
  UpdateLayout;
  ScanAndDisplayProjects;
end;

procedure TMainWindow.SortComboChange(Sender: TObject);
begin
  SortProjects;
  RefreshProjectListUI;
  ProjectListBox.Invalidate;
end;

procedure TMainWindow.btnMenuClick(Sender: TObject);
var
  Theme: TAppTheme;
begin
  Theme := GetAppTheme;
  if ShowThemeSettingsDialog(Theme) then
  begin
    SetAppTheme(Theme, True);
    ApplyTheme;
  end;
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
  IsDark: Boolean;
begin
  IsDark := GetAppTheme = atDark;
  P := GetThemePalette(GetAppTheme);
  if IsDark then
  begin
    Color := P.WindowBg;
    HeaderPanel.Color := P.HeaderBg;
    LeftRail.Color := P.RailBg;
    ContentPanel.Color := P.ContentBg;
    ProjectsTablePanel.Color := P.PanelBg;
    WelcomePanel.Color := P.PanelBg;
    StatusBar.Color := P.StatusBg;
    StatusBar.Font.Color := P.HeaderText;
    ProjectListBox.Color := P.PanelBg;
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
  end
  else
  begin
    Color := P.WindowBg;
    HeaderPanel.Color := P.HeaderBg;
    LeftRail.Color := P.RailBg;
    ContentPanel.Color := P.ContentBg;
    ProjectsTablePanel.Color := P.PanelBg;
    WelcomePanel.Color := P.PanelBg;
    StatusBar.Color := P.StatusBg;
    StatusBar.Font.Color := clWhite;
    ProjectListBox.Color := P.PanelBg;
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
    lblWelcome.Font.Color := clBlack;
    lblWelcomeMsg.Font.Color := P.TextSecondary;
    btnMenu.Font.Color := P.RailText;
    AddProjectCircle.Brush.Color := P.Accent;
    AddProjectCircle.Pen.Color := P.Accent;
    btnAddProject.Font.Color := P.TextInverse;
  end;
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

procedure TMainWindow.SortProjects;
begin
  if Length(FProjects) <= 1 then
    Exit;
  QuickSortProjects(FProjects, 0, High(FProjects), cmbSortBy.ItemIndex,
    cmbSortColumnBy.ItemIndex);
end;

procedure TMainWindow.RefreshProjectListUI;
var
  I, IssueCount: Integer;
begin
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
    ProjectListBox.Visible := False;
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
    ProjectListBox.Visible := True;
    ProjectListBox.Items.Clear;
    for I := 0 to Length(FProjects) - 1 do
      ProjectListBox.Items.Add(ProjectDisplayName(FProjects[I]));

    if IssueCount > 0 then
      StatusBar.Panels[0].Text := Format(rsProjectsFoundWithIssuesFmt,
        [Length(FProjects), IssueCount])
    else
      StatusBar.Panels[0].Text := Format(rsProjectsFoundFmt, [Length(FProjects)]);
  end;
end;

procedure TMainWindow.ProjectListBoxClick(Sender: TObject);
begin
  OpenProjectAtIndex(ProjectListBox.ItemIndex);
end;

procedure TMainWindow.OpenProjectAtIndex(Idx: Integer);
var
  EditForm: TProjectEditWindow;
  ShownModal: Boolean;
begin
  if (Idx < 0) or (Idx >= Length(FProjects)) then
    Exit;
  if FProjects[Idx].HasIssues then
  begin
    ShowMessage(rsProjectCannotOpenUntilIssuesFixedPrefix +
      FProjects[Idx].IssueSummary);
    Exit;
  end;

  ShownModal := False;
  EditForm := TProjectEditWindow.Create(nil);
  try
    EditForm.OpenProject(FProjects[Idx].FullPath, FProjects[Idx]);
    ShownModal := True;
    EditForm.ShowModal;
  except
    on E: Exception do
    begin
      if (not ShownModal) and (EditForm <> nil) and
         not (csDestroying in EditForm.ComponentState) then
        FreeAndNil(EditForm);
      ShowMessage(rsProjectOpenSafelyAbortedPrefix +
        E.Message);
    end;
  end;

  { Refresh project list after returning }
  ScanAndDisplayProjects;
end;

function TMainWindow.IsInfoIconHit(Index, X, Y: Integer): Boolean;
var
  ItemRect: TRect;
  IconX, IconY, DX, DY: Integer;
begin
  Result := False;
  if (Index < 0) or (Index >= ProjectListBox.Items.Count) then
    Exit;
  ItemRect := ProjectListBox.ItemRect(Index);
  if (X < ItemRect.Left) or (X >= ItemRect.Right) or
     (Y < ItemRect.Top) or (Y >= ItemRect.Bottom) then
    Exit;
  IconX := ItemRect.Right - 30;
  IconY := (ItemRect.Top + ItemRect.Bottom) div 2;
  DX := X - IconX;
  DY := Y - IconY;
  Result := (DX * DX + DY * DY) <= (10 * 10);
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
  ScanAndDisplayProjects;
end;

procedure TMainWindow.ProjectListBoxMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  Idx: Integer;
begin
  if Button <> mbLeft then
    Exit;
  Idx := ProjectListBox.ItemAtPos(Point(X, Y), True);
  if (Idx < 0) or (Idx >= Length(FProjects)) then
    Exit;
  ProjectListBox.ItemIndex := Idx;
  if IsInfoIconHit(Idx, X, Y) then
    ShowProjectDetails(Idx)
  else
    OpenProjectAtIndex(Idx);
end;

procedure TMainWindow.ProjectListBoxMouseMove(Sender: TObject;
  Shift: TShiftState; X, Y: Integer);
var
  Idx: Integer;
  NewHint: string;
begin
  Idx := ProjectListBox.ItemAtPos(Point(X, Y), True);
  if (Idx >= 0) and IsInfoIconHit(Idx, X, Y) then
    NewHint := rsHintDetails
  else
    NewHint := '';
  if ProjectListBox.Hint <> NewHint then
    ProjectListBox.Hint := NewHint;
end;

procedure TMainWindow.StartNewProjectFlow;
var
  TargetLangCode, TargetLangName: string;
  BookCode, BookName: string;
  SourceOpt: TSourceTextOption;
  NewProjectDir, Err: string;
begin
  if not PromptForTargetLanguage(TargetLangCode, TargetLangName) then
    Exit;

  if not PromptForBook(BookCode, BookName) then
    Exit;

  if not PromptForSourceText(Trim(BookCode), SourceOpt) then
    Exit;

  if not CreateProjectFromSource(Trim(TargetLangCode), Trim(TargetLangName), SourceOpt, NewProjectDir, Err) then
  begin
    ShowMessage(Err);
    ScanAndDisplayProjects;
    Exit;
  end;

  ShowMessage(rsProjectCreatedPrefix + NewProjectDir);
  ScanAndDisplayProjects;
end;

procedure TMainWindow.ProjectListBoxDrawItem(Control: TWinControl;
  Index: Integer; ARect: TRect; State: TOwnerDrawState);
var
  Cvs: TCanvas;
  S: TProjectSummary;
  DisplayName: string;
  ProgressPct: Integer;
  RowTop: Integer;
  ProjectX, TypeX, LanguageX: Integer;
  PieCenterX, PieCenterY, PieRadius: Integer;
  PieEndX, PieEndY: Integer;
  SweepAngle: Double;
  InfoCenterX, InfoCenterY, InfoRadius: Integer;
  ProgressBlue: TColor;
  ProjectTextColor, MetaTextColor: TColor;
  TypeLabel: string;
begin
  if (Index < 0) or (Index >= Length(FProjects)) then
    Exit;

  Cvs := ProjectListBox.Canvas;
  S := FProjects[Index];
  ProgressBlue := $00A7E8;

  { Background }
  if odSelected in State then
    Cvs.Brush.Color := $00F2E8DA
  else if (Index mod 2) = 0 then
    Cvs.Brush.Color := clWhite
  else
    Cvs.Brush.Color := $00FCFCFC;

  Cvs.FillRect(ARect);

  { Draw separator line }
  Cvs.Pen.Color := $00E6E6E6;
  Cvs.Line(ARect.Left, ARect.Bottom - 1, ARect.Right, ARect.Bottom - 1);

  RowTop := ARect.Top;
  ProjectX := ARect.Left + 60;
  TypeX := ARect.Left + Round((ARect.Right - ARect.Left) * 0.37);
  LanguageX := ARect.Left + Round((ARect.Right - ARect.Left) * 0.53);

  { Document icon }
  Cvs.Pen.Color := $006E6E6E;
  Cvs.Brush.Color := clWhite;
  Cvs.Rectangle(ARect.Left + 22, RowTop + 20, ARect.Left + 38, RowTop + 36);
  Cvs.MoveTo(ARect.Left + 25, RowTop + 24);
  Cvs.LineTo(ARect.Left + 35, RowTop + 24);
  Cvs.MoveTo(ARect.Left + 25, RowTop + 28);
  Cvs.LineTo(ARect.Left + 35, RowTop + 28);
  Cvs.MoveTo(ARect.Left + 25, RowTop + 32);
  Cvs.LineTo(ARect.Left + 33, RowTop + 32);

  { Issue marker }
  if S.HasIssues then
  begin
    Cvs.Pen.Style := psClear;
    Cvs.Brush.Color := clRed;
    Cvs.Ellipse(ARect.Left + 8, RowTop + 25, ARect.Left + 18, RowTop + 35);
    Cvs.Pen.Style := psSolid;
  end;

  { Project name }
  if S.HasIssues then
  begin
    ProjectTextColor := clRed;
    MetaTextColor := clRed;
  end
  else
  begin
    ProjectTextColor := $00202020;
    MetaTextColor := $00858585;
  end;

  Cvs.Brush.Style := bsClear;
  Cvs.Font.Style := [];
  Cvs.Font.Height := -15;
  Cvs.Font.Color := ProjectTextColor;
  DisplayName := Trim(S.BookName);
  if DisplayName = '' then
    DisplayName := Trim(S.DirName);
  if DisplayName = '' then
    DisplayName := ExtractFileName(ExcludeTrailingPathDelimiter(S.FullPath));
  if DisplayName = '' then
    DisplayName := rsTypeUnknown;
  Cvs.TextOut(ProjectX, RowTop + 20, DisplayName);

  { Type }
  Cvs.Font.Style := [];
  Cvs.Font.Height := -12;
  Cvs.Font.Color := MetaTextColor;
  if Trim(S.ResourceType) = '' then
    TypeLabel := rsTypeUnknown
  else
    TypeLabel := rsTypeTextPrefix + S.ResourceType;
  Cvs.TextOut(TypeX, RowTop + 23, TypeLabel);

  { Language }
  Cvs.Font.Color := MetaTextColor;
  Cvs.TextOut(LanguageX, RowTop + 23, S.TargetLangName);
  Cvs.Brush.Style := bsSolid;

  { Progress }
  if S.TotalChunks > 0 then
    ProgressPct := (S.FinishedChunks * 100) div S.TotalChunks
  else
    ProgressPct := 0;
  PieCenterX := ARect.Right - 100;
  PieCenterY := RowTop + ((ARect.Bottom - ARect.Top) div 2);
  PieRadius := 15;

  Cvs.Pen.Style := psClear;
  Cvs.Brush.Color := $00D8D8D8;
  Cvs.Ellipse(PieCenterX - PieRadius, PieCenterY - PieRadius,
              PieCenterX + PieRadius, PieCenterY + PieRadius);
  if ProgressPct > 0 then
  begin
    SweepAngle := 2 * Pi * (ProgressPct / 100.0) - (Pi / 2);
    PieEndX := PieCenterX + Round(Cos(SweepAngle) * PieRadius);
    PieEndY := PieCenterY + Round(Sin(SweepAngle) * PieRadius);
    Cvs.Brush.Color := ProgressBlue;
    Cvs.Pie(PieCenterX - PieRadius, PieCenterY - PieRadius,
            PieCenterX + PieRadius, PieCenterY + PieRadius,
            PieCenterX, PieCenterY - PieRadius, PieEndX, PieEndY);
  end;
  Cvs.Pen.Style := psSolid;

  { Info icon }
  InfoCenterX := ARect.Right - 30;
  InfoCenterY := PieCenterY;
  InfoRadius := 10;
  Cvs.Pen.Color := $00B8B8B8;
  Cvs.Brush.Color := $00B8B8B8;
  Cvs.Ellipse(InfoCenterX - InfoRadius, InfoCenterY - InfoRadius,
              InfoCenterX + InfoRadius, InfoCenterY + InfoRadius);
  Cvs.Font.Height := -12;
  Cvs.Font.Color := clWhite;
  Cvs.TextOut(InfoCenterX - 3, InfoCenterY - 7, 'i');
end;

procedure TMainWindow.StatusBarDrawPanel(AStatusBar: TStatusBar;
  Panel: TStatusPanel; const Rect: TRect);
var
  P: TThemePalette;
  TextY: Integer;
begin
  P := GetThemePalette(GetAppTheme);
  AStatusBar.Canvas.Brush.Color := AStatusBar.Color;
  AStatusBar.Canvas.FillRect(Rect);
  AStatusBar.Canvas.Font.Assign(AStatusBar.Font);
  if GetAppTheme = atLight then
    AStatusBar.Canvas.Font.Color := clWhite
  else
    AStatusBar.Canvas.Font.Color := P.HeaderText;
  TextY := Rect.Top + ((Rect.Bottom - Rect.Top - AStatusBar.Canvas.TextHeight(Panel.Text)) div 2);
  AStatusBar.Canvas.TextOut(Rect.Left + 8, TextY, Panel.Text);
end;

end.
