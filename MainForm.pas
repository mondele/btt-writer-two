unit MainForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, Math,
  ExtCtrls, StdCtrls, Buttons, ComCtrls, LCLType,
  Globals, ProjectScanner, ProjectEditForm, ProjectCreator, ProjectManager;

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
    procedure btnStartProjectClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormResize(Sender: TObject);
  private
    ProjectListBox: TListBox;
    FProjects: TProjectSummaryList;
    procedure UpdateLayout;
    procedure EnsureSourcesForProjects;
    procedure ScanAndDisplayProjects;
    procedure ProjectListBoxClick(Sender: TObject);
    procedure ProjectListBoxDrawItem(Control: TWinControl; Index: Integer;
      ARect: TRect; State: TOwnerDrawState);
    procedure StartNewProjectFlow;
  public
  end;

var
  MainWindow: TMainWindow;

implementation

{$R *.lfm}

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
  Caption := APP_NAME + ' ' + APP_VERSION;
  lblCurrentUser.Caption := 'Current User: Raphael';
  btnLogout.Caption := '(Logout)';

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
  ProjectListBox.OnClick := @ProjectListBoxClick;
  ProjectListBox.OnDrawItem := @ProjectListBoxDrawItem;
  ProjectListBox.BorderStyle := bsNone;
  ProjectListBox.Color := clWhite;
  ProjectListBox.Visible := False;
  btnAddProject.OnClick := @btnAddProjectClick;
  btnStartProject.OnClick := @btnStartProjectClick;

  UpdateLayout;
  ScanAndDisplayProjects;
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

procedure TMainWindow.EnsureSourcesForProjects;
var
  I, FailCount: Integer;
  P: TProject;
  SourceOpt: TSourceTextOption;
  SourceDir, Err, FailMsg: string;
begin
  FailCount := 0;
  FailMsg := '';

  for I := 0 to Length(FProjects) - 1 do
  begin
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
    ShowMessage('Some project sources could not be prepared (' +
      IntToStr(FailCount) + '). First error: ' + FailMsg);
end;

procedure TMainWindow.ScanAndDisplayProjects;
var
  I: Integer;
begin
  FProjects := ScanProjects;
  EnsureSourcesForProjects;

  if Length(FProjects) = 0 then
  begin
    WelcomePanel.Visible := True;
    ProjectsTablePanel.Visible := False;
    lblProjectColumn.Visible := False;
    lblTypeColumn.Visible := False;
    lblLanguageColumn.Visible := False;
    lblProgressColumn.Visible := False;
    ProjectListBox.Visible := False;
    StatusBar.Panels[0].Text := 'No projects found';
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
      ProjectListBox.Items.Add(FProjects[I].BookName);

    StatusBar.Panels[0].Text := Format('%d project(s) found', [Length(FProjects)]);
  end;
end;

procedure TMainWindow.ProjectListBoxClick(Sender: TObject);
var
  Idx: Integer;
  EditForm: TProjectEditWindow;
  ShownModal: Boolean;
begin
  Idx := ProjectListBox.ItemIndex;
  if (Idx < 0) or (Idx >= Length(FProjects)) then
    Exit;

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
      ShowMessage('Project could not be opened and was safely aborted: ' +
        E.Message);
    end;
  end;

  { Refresh project list after returning }
  ScanAndDisplayProjects;
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

  ShowMessage('Project created: ' + NewProjectDir);
  ScanAndDisplayProjects;
end;

procedure TMainWindow.ProjectListBoxDrawItem(Control: TWinControl;
  Index: Integer; ARect: TRect; State: TOwnerDrawState);
var
  Cvs: TCanvas;
  S: TProjectSummary;
  ProgressPct: Integer;
  RowTop: Integer;
  ProjectX, TypeX, LanguageX: Integer;
  PieCenterX, PieCenterY, PieRadius: Integer;
  PieEndX, PieEndY: Integer;
  SweepAngle: Double;
  InfoCenterX, InfoCenterY, InfoRadius: Integer;
  ProgressBlue: TColor;
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

  { Project name }
  Cvs.Font.Style := [];
  Cvs.Font.Height := -15;
  Cvs.Font.Color := $00202020;
  Cvs.TextOut(ProjectX, RowTop + 20, S.BookName);

  { Type }
  Cvs.Font.Style := [];
  Cvs.Font.Height := -12;
  Cvs.Font.Color := $00858585;
  Cvs.TextOut(TypeX, RowTop + 23, 'Text ' + S.ResourceType);

  { Language }
  Cvs.TextOut(LanguageX, RowTop + 23, S.TargetLangName);

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

end.
