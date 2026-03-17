unit ConflictResolver;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes;

{ Show the conflict resolution dialog for a project.
  Returns True if all conflicts were resolved, False if cancelled. }
function ShowConflictResolver(const ProjectDir, BookName, LangName: string): Boolean;

implementation

uses
  Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls, IpHtml,
  ThemePalette, AppSettings, UIFonts, AppLog, GitUtils;

resourcestring
  rsConflictTitle = 'Resolve Merge Conflicts';
  rsConflictHeader = 'Conflict %d of %d — %s';
  rsConflictLocal = 'Local Version (yours)';
  rsConflictImported = 'Imported Version (theirs)';
  rsConflictConfirm = 'CONFIRM';
  rsConflictCancel = 'CANCEL';
  rsConflictNext = 'Next →';
  rsConflictPrev = '← Previous';
  rsSelectVersion = 'Click on the version you want to keep.';
  rsAllResolved = 'All conflicts resolved.';
  rsConflictFilePrefix = 'File: ';

type
  TConflictItem = record
    RelPath: string;
    OursText: string;
    TheirsText: string;
    ChosenText: string;  { empty until user picks }
    Resolved: Boolean;
  end;

  TConflictResolverForm = class(TForm)
  private
    FProjectDir: string;
    FBookName: string;
    FLangName: string;
    FConflicts: array of TConflictItem;
    FCurrentIndex: Integer;

    { UI elements }
    FTopPanel: TPanel;
    FHeaderLabel: TLabel;
    FFileLabel: TLabel;
    FInstructionLabel: TLabel;

    FContentPanel: TPanel;
    FOursPanel: TPanel;
    FOursLabel: TLabel;
    FOursHtml: TIpHtmlPanel;
    FTheirsPanel: TPanel;
    FTheirsLabel: TLabel;
    FTheirsHtml: TIpHtmlPanel;

    FBottomPanel: TPanel;
    FBtnPrev: TButton;
    FBtnNext: TButton;
    FBtnConfirm: TButton;
    FBtnCancel: TButton;

    FSelectedSide: Integer; { 0=none, 1=ours, 2=theirs }

    procedure LoadConflicts;
    procedure ShowConflict(AIndex: Integer);
    procedure UpdateNav;
    procedure ResolveCurrentAs(const AText: string; ASide: Integer);
    procedure SelectOurs(Sender: TObject);
    procedure SelectTheirs(Sender: TObject);
    procedure UpdateSelectionHighlight;
    procedure BtnPrevClick(Sender: TObject);
    procedure BtnNextClick(Sender: TObject);
    procedure BtnConfirmClick(Sender: TObject);
    procedure SetHtmlContent(APanel: TIpHtmlPanel; const AText: string);
    function ChunkLabel(const RelPath: string): string;
    function AllResolved: Boolean;
  end;

procedure TConflictResolverForm.LoadConflicts;
var
  Files: TStringArray;
  I: Integer;
  SL: TStringList;
  Content: string;
begin
  Files := ListConflictFiles(FProjectDir);
  SetLength(FConflicts, Length(Files));
  for I := 0 to Length(Files) - 1 do
  begin
    FConflicts[I].RelPath := Files[I];
    FConflicts[I].Resolved := False;
    FConflicts[I].ChosenText := '';

    { Read the file with conflict markers }
    SL := TStringList.Create;
    try
      try
        SL.LoadFromFile(IncludeTrailingPathDelimiter(FProjectDir) + Files[I]);
        Content := SL.Text;
      except
        Content := '';
      end;
    finally
      SL.Free;
    end;

    ParseConflictMarkers(Content, FConflicts[I].OursText, FConflicts[I].TheirsText);
  end;
end;

function TConflictResolverForm.ChunkLabel(const RelPath: string): string;
var
  Parts: TStringArray;
  ChDir, ChFile: string;
begin
  { RelPath is like '03/01.txt' → 'Chapter 3 : v1' }
  Parts := RelPath.Split('/');
  if Length(Parts) >= 2 then
  begin
    ChDir := Parts[Length(Parts) - 2];
    ChFile := ChangeFileExt(Parts[Length(Parts) - 1], '');
    if ChDir = 'front' then
      Result := 'Title'
    else
      Result := FBookName + ' ' + ChDir + ':' + ChFile + ' — ' + FLangName;
  end
  else
    Result := RelPath;
end;

procedure TConflictResolverForm.SetHtmlContent(APanel: TIpHtmlPanel;
  const AText: string);
var
  SS: TStringStream;
  HtmlDoc: TIpHtml;
  Escaped, HtmlStr: string;
begin
  Escaped := StringReplace(AText, '&', '&amp;', [rfReplaceAll]);
  Escaped := StringReplace(Escaped, '<', '&lt;', [rfReplaceAll]);
  Escaped := StringReplace(Escaped, '>', '&gt;', [rfReplaceAll]);
  Escaped := StringReplace(Escaped, LineEnding, '<br>', [rfReplaceAll]);
  Escaped := StringReplace(Escaped, #10, '<br>', [rfReplaceAll]);

  HtmlStr := '<html><body style="font-family: Roboto, sans-serif; font-size: 14pt; ' +
    'padding: 8px;">' + Escaped + '</body></html>';

  SS := TStringStream.Create(HtmlStr);
  try
    HtmlDoc := TIpHtml.Create;
    HtmlDoc.LoadFromStream(SS);
    APanel.SetHtml(HtmlDoc);
  finally
    SS.Free;
  end;
end;

procedure TConflictResolverForm.ShowConflict(AIndex: Integer);
begin
  if (AIndex < 0) or (AIndex >= Length(FConflicts)) then
    Exit;
  FCurrentIndex := AIndex;

  FHeaderLabel.Caption := Format(rsConflictHeader,
    [AIndex + 1, Length(FConflicts), ChunkLabel(FConflicts[AIndex].RelPath)]);
  FFileLabel.Caption := rsConflictFilePrefix + FConflicts[AIndex].RelPath;

  SetHtmlContent(FOursHtml, FConflicts[AIndex].OursText);
  SetHtmlContent(FTheirsHtml, FConflicts[AIndex].TheirsText);

  { Restore selection state }
  if FConflicts[AIndex].Resolved then
  begin
    if FConflicts[AIndex].ChosenText = FConflicts[AIndex].OursText then
      FSelectedSide := 1
    else
      FSelectedSide := 2;
  end
  else
    FSelectedSide := 0;

  UpdateSelectionHighlight;
  UpdateNav;
end;

procedure TConflictResolverForm.ResolveCurrentAs(const AText: string; ASide: Integer);
var
  Err: string;
begin
  FSelectedSide := ASide;
  FConflicts[FCurrentIndex].ChosenText := AText;

  { Write and stage immediately }
  if ResolveConflictFile(FProjectDir, FConflicts[FCurrentIndex].RelPath, AText, Err) then
    FConflicts[FCurrentIndex].Resolved := True
  else
    ShowMessage('Error resolving ' + FConflicts[FCurrentIndex].RelPath + ': ' + Err);

  UpdateSelectionHighlight;
  UpdateNav;
end;

procedure TConflictResolverForm.SelectOurs(Sender: TObject);
begin
  ResolveCurrentAs(FConflicts[FCurrentIndex].OursText, 1);
end;

procedure TConflictResolverForm.SelectTheirs(Sender: TObject);
begin
  ResolveCurrentAs(FConflicts[FCurrentIndex].TheirsText, 2);
end;

procedure TConflictResolverForm.UpdateSelectionHighlight;
var
  Pal: TThemePalette;
begin
  Pal := GetThemePalette(GetEffectiveTheme);
  case FSelectedSide of
    1: begin
      FOursPanel.Color := $00E8F5E9;   { light green }
      FTheirsPanel.Color := $00FFEBEE;  { light red/pink }
    end;
    2: begin
      FOursPanel.Color := $00FFEBEE;    { light red/pink }
      FTheirsPanel.Color := $00E8F5E9;  { light green }
    end;
  else
    begin
      FOursPanel.Color := $00E3F2FD;    { light blue - neutral }
      FTheirsPanel.Color := $00FFF3E0;  { light orange - neutral }
    end;
  end;
end;

procedure TConflictResolverForm.UpdateNav;
begin
  FBtnPrev.Enabled := FCurrentIndex > 0;
  FBtnNext.Enabled := FCurrentIndex < Length(FConflicts) - 1;
  FBtnConfirm.Enabled := AllResolved;
end;

procedure TConflictResolverForm.BtnPrevClick(Sender: TObject);
begin
  if FCurrentIndex > 0 then
    ShowConflict(FCurrentIndex - 1);
end;

procedure TConflictResolverForm.BtnNextClick(Sender: TObject);
begin
  if FCurrentIndex < Length(FConflicts) - 1 then
    ShowConflict(FCurrentIndex + 1);
end;

procedure TConflictResolverForm.BtnConfirmClick(Sender: TObject);
var
  Err: string;
begin
  if not AllResolved then
    Exit;

  { All files already written and staged — finalize the merge commit }
  if not FinalizeMerge(FProjectDir, Err) then
  begin
    ShowMessage('Error finalizing merge: ' + Err);
    Exit;
  end;

  ModalResult := mrOK;
end;

function TConflictResolverForm.AllResolved: Boolean;
var
  I: Integer;
begin
  Result := True;
  for I := 0 to Length(FConflicts) - 1 do
    if not FConflicts[I].Resolved then
      Exit(False);
end;

function ShowConflictResolver(const ProjectDir, BookName, LangName: string): Boolean;
var
  F: TConflictResolverForm;
  Pal: TThemePalette;
begin
  Result := False;
  Pal := GetThemePalette(GetEffectiveTheme);

  F := TConflictResolverForm.CreateNew(nil);
  try
    F.FProjectDir := ProjectDir;
    F.FBookName := BookName;
    F.FLangName := LangName;
    F.FCurrentIndex := 0;
    F.FSelectedSide := 0;
    F.Position := poScreenCenter;
    F.BorderStyle := bsSizeable;
    F.Caption := rsConflictTitle;
    F.Width := 700;
    F.Height := 600;
    F.Color := Pal.PanelBg;
    F.Font.Name := 'Noto Sans';

    { Top panel with header }
    F.FTopPanel := TPanel.Create(F);
    F.FTopPanel.Parent := F;
    F.FTopPanel.Align := alTop;
    F.FTopPanel.Height := 80;
    F.FTopPanel.BevelOuter := bvNone;
    F.FTopPanel.Color := Pal.PanelBg;

    F.FHeaderLabel := TLabel.Create(F);
    F.FHeaderLabel.Parent := F.FTopPanel;
    F.FHeaderLabel.SetBounds(16, 8, 660, 24);
    F.FHeaderLabel.Font.Height := -16;
    F.FHeaderLabel.Font.Style := [fsBold];
    F.FHeaderLabel.Font.Color := Pal.TextPrimary;

    F.FFileLabel := TLabel.Create(F);
    F.FFileLabel.Parent := F.FTopPanel;
    F.FFileLabel.SetBounds(16, 34, 660, 18);
    F.FFileLabel.Font.Height := -12;
    F.FFileLabel.Font.Color := Pal.TextMuted;

    F.FInstructionLabel := TLabel.Create(F);
    F.FInstructionLabel.Parent := F.FTopPanel;
    F.FInstructionLabel.SetBounds(16, 56, 660, 18);
    F.FInstructionLabel.Font.Height := -13;
    F.FInstructionLabel.Font.Color := Pal.TextSecondary;
    F.FInstructionLabel.Caption := rsSelectVersion;

    { Bottom panel with buttons }
    F.FBottomPanel := TPanel.Create(F);
    F.FBottomPanel.Parent := F;
    F.FBottomPanel.Align := alBottom;
    F.FBottomPanel.Height := 50;
    F.FBottomPanel.BevelOuter := bvNone;
    F.FBottomPanel.Color := Pal.PanelBg;

    F.FBtnPrev := TButton.Create(F);
    F.FBtnPrev.Parent := F.FBottomPanel;
    F.FBtnPrev.SetBounds(16, 10, 90, 30);
    F.FBtnPrev.Caption := rsConflictPrev;
    F.FBtnPrev.OnClick := @F.BtnPrevClick;

    F.FBtnNext := TButton.Create(F);
    F.FBtnNext.Parent := F.FBottomPanel;
    F.FBtnNext.SetBounds(116, 10, 90, 30);
    F.FBtnNext.Caption := rsConflictNext;
    F.FBtnNext.OnClick := @F.BtnNextClick;

    F.FBtnCancel := TButton.Create(F);
    F.FBtnCancel.Parent := F.FBottomPanel;
    F.FBtnCancel.SetBounds(460, 10, 90, 30);
    F.FBtnCancel.Caption := rsConflictCancel;
    F.FBtnCancel.ModalResult := mrCancel;

    F.FBtnConfirm := TButton.Create(F);
    F.FBtnConfirm.Parent := F.FBottomPanel;
    F.FBtnConfirm.SetBounds(560, 10, 110, 30);
    F.FBtnConfirm.Caption := rsConflictConfirm;
    F.FBtnConfirm.Font.Style := [fsBold];
    F.FBtnConfirm.OnClick := @F.BtnConfirmClick;

    { Content panel — split into ours (top) and theirs (bottom) }
    F.FContentPanel := TPanel.Create(F);
    F.FContentPanel.Parent := F;
    F.FContentPanel.Align := alClient;
    F.FContentPanel.BevelOuter := bvNone;

    { Ours panel (top half) }
    F.FOursPanel := TPanel.Create(F);
    F.FOursPanel.Parent := F.FContentPanel;
    F.FOursPanel.Align := alTop;
    F.FOursPanel.Height := 220;
    F.FOursPanel.BevelOuter := bvLowered;
    F.FOursPanel.Cursor := crHandPoint;
    F.FOursPanel.OnClick := @F.SelectOurs;

    F.FOursLabel := TLabel.Create(F);
    F.FOursLabel.Parent := F.FOursPanel;
    F.FOursLabel.Align := alTop;
    F.FOursLabel.Height := 22;
    F.FOursLabel.Caption := '  ' + rsConflictLocal;
    F.FOursLabel.Font.Height := -12;
    F.FOursLabel.Font.Style := [fsBold];
    F.FOursLabel.Font.Color := Pal.TextSecondary;
    F.FOursLabel.Layout := tlCenter;
    F.FOursLabel.Cursor := crHandPoint;
    F.FOursLabel.OnClick := @F.SelectOurs;

    F.FOursHtml := TIpHtmlPanel.Create(F);
    F.FOursHtml.Parent := F.FOursPanel;
    F.FOursHtml.Align := alClient;
    F.FOursHtml.Cursor := crHandPoint;
    F.FOursHtml.OnClick := @F.SelectOurs;

    { Splitter between panels }
    with TSplitter.Create(F) do
    begin
      Parent := F.FContentPanel;
      Align := alTop;
      Height := 5;
      Top := F.FOursPanel.Top + F.FOursPanel.Height + 1;
      MinSize := 80;
    end;

    { Theirs panel (bottom half) }
    F.FTheirsPanel := TPanel.Create(F);
    F.FTheirsPanel.Parent := F.FContentPanel;
    F.FTheirsPanel.Align := alClient;
    F.FTheirsPanel.BevelOuter := bvLowered;
    F.FTheirsPanel.Cursor := crHandPoint;
    F.FTheirsPanel.OnClick := @F.SelectTheirs;

    F.FTheirsLabel := TLabel.Create(F);
    F.FTheirsLabel.Parent := F.FTheirsPanel;
    F.FTheirsLabel.Align := alTop;
    F.FTheirsLabel.Height := 22;
    F.FTheirsLabel.Caption := '  ' + rsConflictImported;
    F.FTheirsLabel.Font.Height := -12;
    F.FTheirsLabel.Font.Style := [fsBold];
    F.FTheirsLabel.Font.Color := Pal.TextSecondary;
    F.FTheirsLabel.Layout := tlCenter;
    F.FTheirsLabel.Cursor := crHandPoint;
    F.FTheirsLabel.OnClick := @F.SelectTheirs;

    F.FTheirsHtml := TIpHtmlPanel.Create(F);
    F.FTheirsHtml.Parent := F.FTheirsPanel;
    F.FTheirsHtml.Align := alClient;
    F.FTheirsHtml.Cursor := crHandPoint;
    F.FTheirsHtml.OnClick := @F.SelectTheirs;

    ApplyFontRecursive(F, 'Noto Sans');

    { Load and display conflicts }
    F.LoadConflicts;
    if Length(F.FConflicts) = 0 then
    begin
      ShowMessage(rsAllResolved);
      Exit(True);
    end;
    F.ShowConflict(0);

    Result := F.ShowModal = mrOK;
  finally
    F.Free;
  end;
end;

end.
