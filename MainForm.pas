unit MainForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs,
  ExtCtrls, StdCtrls, Buttons, ComCtrls, LCLType,
  Globals, ProjectScanner, ProjectEditForm;

type
  TMainWindow = class(TForm)
    HeaderPanel: TPanel;
    lblAppName: TLabel;
    lblCurrentUser: TLabel;
    btnLogout: TLabel;
    ContentPanel: TPanel;
    lblProjectsHeading: TLabel;
    WelcomePanel: TPanel;
    lblWelcome: TLabel;
    lblWelcomeMsg: TLabel;
    btnStartProject: TButton;
    btnAddProject: TSpeedButton;
    btnMenu: TSpeedButton;
    StatusBar: TStatusBar;
    procedure FormCreate(Sender: TObject);
  private
    ProjectListBox: TListBox;
    FProjects: TProjectSummaryList;
    procedure ScanAndDisplayProjects;
    procedure ProjectListBoxClick(Sender: TObject);
    procedure ProjectListBoxDrawItem(Control: TWinControl; Index: Integer;
      ARect: TRect; State: TOwnerDrawState);
  public
  end;

var
  MainWindow: TMainWindow;

implementation

{$R *.lfm}

procedure TMainWindow.FormCreate(Sender: TObject);
begin
  Caption := APP_NAME + ' ' + APP_VERSION;

  { Create project list box }
  ProjectListBox := TListBox.Create(Self);
  ProjectListBox.Parent := ContentPanel;
  ProjectListBox.Left := 16;
  ProjectListBox.Top := 44;
  ProjectListBox.Width := ContentPanel.Width - 32;
  ProjectListBox.Height := ContentPanel.Height - 52;
  ProjectListBox.Anchors := [akTop, akLeft, akRight, akBottom];
  ProjectListBox.Style := lbOwnerDrawFixed;
  ProjectListBox.ItemHeight := 56;
  ProjectListBox.OnClick := @ProjectListBoxClick;
  ProjectListBox.OnDrawItem := @ProjectListBoxDrawItem;
  ProjectListBox.BorderStyle := bsNone;
  ProjectListBox.Color := clWhite;
  ProjectListBox.Visible := False;

  ScanAndDisplayProjects;
end;

procedure TMainWindow.ScanAndDisplayProjects;
var
  I: Integer;
begin
  FProjects := ScanProjects;

  if Length(FProjects) = 0 then
  begin
    WelcomePanel.Visible := True;
    ProjectListBox.Visible := False;
    StatusBar.Panels[0].Text := 'No projects found';
  end
  else
  begin
    WelcomePanel.Visible := False;
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
begin
  Idx := ProjectListBox.ItemIndex;
  if (Idx < 0) or (Idx >= Length(FProjects)) then
    Exit;

  EditForm := TProjectEditWindow.Create(Application);
  EditForm.OpenProject(FProjects[Idx].FullPath, FProjects[Idx]);
  EditForm.ShowModal;

  { Refresh project list after returning }
  ScanAndDisplayProjects;
end;

procedure TMainWindow.ProjectListBoxDrawItem(Control: TWinControl;
  Index: Integer; ARect: TRect; State: TOwnerDrawState);
var
  Cvs: TCanvas;
  S: TProjectSummary;
  ProgressPct: Integer;
  ProgressStr: string;
  TextY: Integer;
begin
  if (Index < 0) or (Index >= Length(FProjects)) then
    Exit;

  Cvs := ProjectListBox.Canvas;
  S := FProjects[Index];

  { Background }
  if odSelected in State then
    Cvs.Brush.Color := $FFE0C0
  else if (Index mod 2) = 0 then
    Cvs.Brush.Color := clWhite
  else
    Cvs.Brush.Color := $FFF8F0;

  Cvs.FillRect(ARect);

  { Draw separator line }
  Cvs.Pen.Color := $E0E0E0;
  Cvs.Line(ARect.Left, ARect.Bottom - 1, ARect.Right, ARect.Bottom - 1);

  TextY := ARect.Top + 6;

  { Book name (bold) }
  Cvs.Font.Style := [fsBold];
  Cvs.Font.Height := -14;
  Cvs.Font.Color := clBlack;
  Cvs.TextOut(ARect.Left + 12, TextY, S.BookName);

  { Resource type }
  Cvs.Font.Style := [];
  Cvs.Font.Height := -11;
  Cvs.Font.Color := clGray;
  Cvs.TextOut(ARect.Left + 12 + Cvs.TextWidth(S.BookName + '  '), TextY + 2,
    '(' + S.ResourceType + ')');

  { Language }
  Cvs.Font.Style := [];
  Cvs.Font.Height := -12;
  Cvs.Font.Color := $404040;
  Cvs.TextOut(ARect.Left + 12, TextY + 22,
    S.TargetLangName + ' (' + S.TargetLangCode + ')');

  { Progress }
  if S.TotalChunks > 0 then
    ProgressPct := (S.FinishedChunks * 100) div S.TotalChunks
  else
    ProgressPct := 0;
  ProgressStr := Format('%d/%d (%d%%)', [S.FinishedChunks, S.TotalChunks, ProgressPct]);

  Cvs.Font.Height := -11;
  Cvs.Font.Color := clGray;
  Cvs.TextOut(ARect.Right - Cvs.TextWidth(ProgressStr) - 16, TextY + 10, ProgressStr);
end;

end.
