unit ProjectEditForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs,
  ExtCtrls, StdCtrls, Buttons,
  ProjectManager, ResourceContainer, ProjectScanner,
  BibleBook, BibleChapter, BibleChunk, USFMUtils, DataPaths;

type
  { Segment of parsed verse text: either a verse badge or plain text }
  TTextSegment = record
    IsVerse: Boolean;
    Text: string;
  end;
  TTextSegmentArray = array of TTextSegment;

  { Custom control that renders USFM text with verse numbers as colored badges }
  TVerseDisplay = class(TCustomControl)
  private
    FText: string;
    FRawText: string;  { original text with \v markers, for save }
    FBadgeColor: TColor;
    FSegments: TTextSegmentArray;
    procedure SetText(const AText: string);
    procedure ParseSegments;
    function DoLayout(ACanvas: TCanvas; AWidth: Integer; ADraw: Boolean): Integer;
  protected
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    function CalcNeededHeight(AWidth: Integer): Integer;
    property Text: string read FRawText write SetText;
    property BadgeColor: TColor read FBadgeColor write FBadgeColor;
  end;

  TChunkPanel = class;

  TProjectEditWindow = class(TForm)
    TopPanel: TPanel;
    btnBack: TButton;
    lblProjectTitle: TLabel;
    lblChapterNav: TLabel;
    btnPrevChapter: TButton;
    lblChapterNum: TLabel;
    btnNextChapter: TButton;
    StatusPanel: TPanel;
    lblStatus: TLabel;
    SplitPanel: TPanel;
    Splitter1: TSplitter;
    SourcePanel: TPanel;
    lblSourceHeader: TLabel;
    SourceScrollBox: TScrollBox;
    TransPanel: TPanel;
    lblTransHeader: TLabel;
    TransScrollBox: TScrollBox;
    AutoSaveTimer: TTimer;
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure btnBackClick(Sender: TObject);
    procedure btnPrevChapterClick(Sender: TObject);
    procedure btnNextChapterClick(Sender: TObject);
    procedure AutoSaveTimerFire(Sender: TObject);
  private
    FProject: TProject;
    FSourceRC: TResourceContainer;
    FCurrentChapterIndex: Integer;
    FChunkPanels: array of TChunkPanel;
    FProjectPath: string;
    FSourceContentDir: string;
    FEnglishULBContentDir: string;

    procedure ClearChunkPanels;
    procedure LoadChapter(AIndex: Integer);
    procedure SaveCurrentChapter;
    procedure UpdateStatus;
    procedure UpdateChapterNav;
    procedure OnChunkFinishedChange(Sender: TObject);
    procedure OnChunkMemoExit(Sender: TObject);
    procedure OnChunkEditClick(Sender: TObject);
  public
    procedure OpenProject(const APath: string; const ASummary: TProjectSummary);
  end;

  TChunkPanel = class
  private
    FSourcePanel: TPanel;
    FTransPanel: TPanel;
    FSourceDisplay: TVerseDisplay;
    FTransDisplay: TVerseDisplay;
    FTransText: string;  { raw USFM text for this chunk }
    FTransMemo: TMemo;
    FEditButton: TButton;
    FFinishedCheck: TCheckBox;
    FChapterID: string;
    FChunkName: string;
    FProject: TProject;
    FEditing: Boolean;
    FOwnerForm: TProjectEditWindow;
  public
    constructor Create(AOwnerForm: TProjectEditWindow;
      ASourceParent, ATransParent: TScrollBox;
      const ASourceText, ATransText, AChapterID, AChunkName, AVerseLabel: string;
      AFinished: Boolean; AProject: TProject; ATopPos: Integer);
    destructor Destroy; override;
    procedure SetEditing(AEdit: Boolean);
    procedure SaveContent;
    function GetHeight: Integer;
    property SourcePanel: TPanel read FSourcePanel;
    property TransPanel: TPanel read FTransPanel;
  end;

var
  ProjectEditWindow: TProjectEditWindow;

implementation

{$R *.lfm}

{ ---- TVerseDisplay ---- }

constructor TVerseDisplay.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FBadgeColor := $D9904A;  { blue-ish }
  FText := '';
  FRawText := '';
  Color := clWhite;
end;

procedure TVerseDisplay.SetText(const AText: string);
begin
  FRawText := AText;
  FText := AText;
  ParseSegments;
  Invalidate;
end;

procedure TVerseDisplay.ParseSegments;
var
  S: string;
  P, NumStart, NumEnd: Integer;
  Count: Integer;
  SegText: string;
begin
  SetLength(FSegments, 0);
  Count := 0;
  S := FText;

  if S = '' then
    Exit;

  P := 1;
  while P <= Length(S) do
  begin
    { Look for \v marker }
    if (S[P] = '\') and (P + 2 <= Length(S)) and (S[P + 1] = 'v') and (S[P + 2] = ' ') then
    begin
      { Extract verse number }
      NumStart := P + 3;
      NumEnd := NumStart;
      while (NumEnd <= Length(S)) and (S[NumEnd] in ['0'..'9', '-']) do
        Inc(NumEnd);

      { Add verse segment }
      Inc(Count);
      SetLength(FSegments, Count);
      FSegments[Count - 1].IsVerse := True;
      FSegments[Count - 1].Text := Copy(S, NumStart, NumEnd - NumStart);

      { Skip optional space after verse number }
      if (NumEnd <= Length(S)) and (S[NumEnd] = ' ') then
        Inc(NumEnd);
      P := NumEnd;
    end
    else
    begin
      { Collect plain text until next \v or end }
      NumStart := P;
      while P <= Length(S) do
      begin
        if (S[P] = '\') and (P + 2 <= Length(S)) and (S[P + 1] = 'v') and (S[P + 2] = ' ') then
          Break;
        Inc(P);
      end;
      SegText := Copy(S, NumStart, P - NumStart);
      if SegText <> '' then
      begin
        Inc(Count);
        SetLength(FSegments, Count);
        FSegments[Count - 1].IsVerse := False;
        FSegments[Count - 1].Text := SegText;
      end;
    end;
  end;
end;

function TVerseDisplay.CalcNeededHeight(AWidth: Integer): Integer;
var
  Bmp: TBitmap;
begin
  { Use a temporary bitmap to measure text without needing a valid handle }
  Bmp := TBitmap.Create;
  try
    Bmp.Canvas.Font.Assign(Font);
    Result := DoLayout(Bmp.Canvas, AWidth, False);
  finally
    Bmp.Free;
  end;
end;

function TVerseDisplay.DoLayout(ACanvas: TCanvas; AWidth: Integer;
  ADraw: Boolean): Integer;
var
  X, Y, MaxW, LineH, BadgeW, BadgeH, BadgePad: Integer;
  WordW, SpaceW: Integer;
  I, J: Integer;
  Lines: TStringList;
  Words: TStringList;
  Word, Line: string;
begin
  ACanvas.Font.Assign(Font);
  LineH := ACanvas.TextHeight('Ag') + 4;
  BadgeH := LineH - 2;
  BadgePad := 5;
  SpaceW := ACanvas.TextWidth(' ');
  MaxW := AWidth - 8;

  X := 4;
  Y := 4;

  for I := 0 to Length(FSegments) - 1 do
  begin
    if FSegments[I].IsVerse then
    begin
      { Draw verse badge }
      BadgeW := ACanvas.TextWidth(FSegments[I].Text) + BadgePad * 2 + 2;
      if (X > 4) and (X + BadgeW > MaxW) then
      begin
        X := 4;
        Y := Y + LineH;
      end;
      if ADraw then
      begin
        ACanvas.Brush.Color := FBadgeColor;
        ACanvas.Pen.Color := FBadgeColor;
        ACanvas.RoundRect(X, Y, X + BadgeW, Y + BadgeH, 8, 8);
        ACanvas.Font.Color := clWhite;
        ACanvas.Font.Style := [fsBold];
        ACanvas.Brush.Style := bsClear;
        ACanvas.TextOut(X + BadgePad + 1, Y + 1, FSegments[I].Text);
        ACanvas.Brush.Style := bsSolid;
        ACanvas.Font.Color := Self.Font.Color;
        ACanvas.Font.Style := Self.Font.Style;
      end;
      X := X + BadgeW + 4;
    end
    else
    begin
      { Draw text with word wrapping, handling embedded newlines }
      Lines := TStringList.Create;
      try
        Lines.Text := FSegments[I].Text;
        for J := 0 to Lines.Count - 1 do
        begin
          Line := Lines[J];
          if (J > 0) then
          begin
            { Newline forces a line break }
            X := 4;
            Y := Y + LineH;
          end;

          Words := TStringList.Create;
          try
            Words.Delimiter := ' ';
            Words.StrictDelimiter := True;
            Words.DelimitedText := Line;

            while Words.Count > 0 do
            begin
              Word := Words[0];
              Words.Delete(0);
              if Word = '' then
                Continue;

              WordW := ACanvas.TextWidth(Word);
              if (X > 4) and (X + WordW > MaxW) then
              begin
                X := 4;
                Y := Y + LineH;
              end;
              if ADraw then
              begin
                ACanvas.Brush.Color := Self.Color;
                ACanvas.TextOut(X, Y + 1, Word);
              end;
              X := X + WordW + SpaceW;
            end;
          finally
            Words.Free;
          end;
        end;
      finally
        Lines.Free;
      end;
    end;
  end;

  Result := Y + LineH + 6;
end;

procedure TVerseDisplay.Paint;
begin
  Canvas.Brush.Color := Color;
  Canvas.FillRect(ClientRect);
  if Length(FSegments) > 0 then
    DoLayout(Canvas, Width, True);
end;

{ ---- TProjectEditWindow ---- }

procedure TProjectEditWindow.FormCreate(Sender: TObject);
begin
  FProject := nil;
  FSourceRC := nil;
  FCurrentChapterIndex := -1;
end;

procedure TProjectEditWindow.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  SaveCurrentChapter;
  ClearChunkPanels;
  FreeAndNil(FProject);
  FreeAndNil(FSourceRC);
  CloseAction := caFree;
end;

procedure TProjectEditWindow.btnBackClick(Sender: TObject);
begin
  Close;
end;

procedure TProjectEditWindow.btnPrevChapterClick(Sender: TObject);
begin
  if FCurrentChapterIndex > 0 then
    LoadChapter(FCurrentChapterIndex - 1);
end;

procedure TProjectEditWindow.btnNextChapterClick(Sender: TObject);
begin
  if (FSourceRC <> nil) and
     (FCurrentChapterIndex < FSourceRC.Book.Chapters.Count - 1) then
    LoadChapter(FCurrentChapterIndex + 1);
end;

procedure TProjectEditWindow.AutoSaveTimerFire(Sender: TObject);
begin
  SaveCurrentChapter;
  lblStatus.Caption := 'Auto-saved at ' + TimeToStr(Now);
end;

procedure TProjectEditWindow.OpenProject(const APath: string;
  const ASummary: TProjectSummary);
begin
  FProjectPath := APath;

  { Find source content directory }
  FSourceContentDir := FindSourceContentDir(ASummary);
  if FSourceContentDir = '' then
  begin
    ShowMessage('Cannot find source text for ' + ASummary.BookCode +
      '. Please ensure it is installed.');
    Close;
    Exit;
  end;

  { Find English ULB for save-chunking }
  FEnglishULBContentDir := FindEnglishULBContentDir(ASummary.BookCode);

  { Load source resource container }
  FSourceRC := TResourceContainer.Create('', ASummary.BookCode, 'ulb', '');
  FSourceRC.Book.LoadFromToc(FSourceContentDir);
  FSourceRC.Book.LoadContent(FSourceContentDir, '.usx');

  { Load project }
  FProject := TProject.Create(APath);
  FProject.LoadContent(FSourceContentDir);

  { Set up title }
  Caption := ASummary.BookName + ' - ' + ASummary.TargetLangName +
    ' (' + ASummary.TargetLangCode + ')';
  lblProjectTitle.Caption := Caption;
  lblSourceHeader.Caption := 'Source Text';
  lblTransHeader.Caption := 'Translation (' + ASummary.TargetLangCode + ')';

  AutoSaveTimer.Enabled := True;

  { Load first chapter (skip 'front' if present) }
  if FSourceRC.Book.Chapters.Count > 0 then
  begin
    if (FSourceRC.Book.Chapters.Count > 1) and
       (FSourceRC.Book.Chapters[0].ID = 'front') then
      LoadChapter(1)
    else
      LoadChapter(0);
  end;
end;

procedure TProjectEditWindow.ClearChunkPanels;
var
  I: Integer;
begin
  for I := 0 to Length(FChunkPanels) - 1 do
    FChunkPanels[I].Free;
  SetLength(FChunkPanels, 0);
end;

procedure TProjectEditWindow.LoadChapter(AIndex: Integer);
var
  SourceChapter, ProjChapter: TChapter;
  I: Integer;
  SourceText, TransText, ChunkLabel: string;
  SourceChunk: TChunk;
  MergedText: string;
  DisplayChunks: TChunkList;
  ChunkMap: TStringList;
  TopPos: Integer;
  IsFinished: Boolean;
  NextChunkStart: Integer;
begin
  { Save previous chapter first }
  SaveCurrentChapter;

  FCurrentChapterIndex := AIndex;
  ClearChunkPanels;

  if FSourceRC = nil then
    Exit;
  if (AIndex < 0) or (AIndex >= FSourceRC.Book.Chapters.Count) then
    Exit;

  SourceChapter := FSourceRC.Book.Chapters[AIndex];

  { Get matching project chapter }
  ProjChapter := nil;
  if FProject.Book <> nil then
    ProjChapter := FProject.Book.GetChapter(SourceChapter.ID);

  { Merge project content into single text, then split by source chunking }
  MergedText := '';
  if ProjChapter <> nil then
    MergedText := ProjChapter.MergeAllContent;

  { Build chunk map from source chapter }
  ChunkMap := TStringList.Create;
  try
    for I := 0 to SourceChapter.Chunks.Count - 1 do
      ChunkMap.Add(SourceChapter.Chunks[I].Name);

    { Split project text by source chunking }
    if MergedText <> '' then
      DisplayChunks := SourceChapter.SplitByChunkMap(MergedText, ChunkMap)
    else
      DisplayChunks := nil;
  finally
    FreeAndNil(ChunkMap);
  end;

  { Build UI panels }
  SetLength(FChunkPanels, SourceChapter.Chunks.Count);
  TopPos := 4;

  for I := 0 to SourceChapter.Chunks.Count - 1 do
  begin
    SourceChunk := SourceChapter.Chunks[I];

    { Convert USX source to plain text }
    SourceText := UsxToPlainText(SourceChunk.Content);

    { Build verse label }
    if SourceChunk.Name = 'title' then
      ChunkLabel := 'Title'
    else
      ChunkLabel := 'v' + SourceChunk.Name;
    { Determine verse range }
    if I < SourceChapter.Chunks.Count - 1 then
    begin
      NextChunkStart := StrToIntDef(SourceChapter.Chunks[I + 1].Name, 0);
      if (NextChunkStart > 0) and (StrToIntDef(SourceChunk.Name, 0) > 0) then
      begin
        if NextChunkStart - StrToIntDef(SourceChunk.Name, 0) > 1 then
          ChunkLabel := 'v' + SourceChunk.Name + '-' +
            IntToStr(NextChunkStart - 1);
      end;
    end;

    { Get translated text for this chunk }
    TransText := '';
    if (DisplayChunks <> nil) and (I < DisplayChunks.Count) then
      TransText := DisplayChunks[I].Content;

    { Check if chunk is finished }
    IsFinished := FProject.IsFinished(SourceChapter.ID, SourceChunk.Name);

    FChunkPanels[I] := TChunkPanel.Create(Self,
      SourceScrollBox, TransScrollBox,
      SourceText, TransText, SourceChapter.ID, SourceChunk.Name,
      ChunkLabel, IsFinished, FProject, TopPos);

    TopPos := TopPos + FChunkPanels[I].GetHeight + 4;
  end;

  if DisplayChunks <> nil then
    FreeAndNil(DisplayChunks);

  UpdateChapterNav;
  UpdateStatus;
end;

procedure TProjectEditWindow.SaveCurrentChapter;
var
  I: Integer;
  SourceChapter: TChapter;
  MergedText: string;
  SaveChunks: TChunkList;
  SaveChunkMap: TStringList;
  SaveContentDir: string;
  SaveChapter: TChapter;
  EnglishBook: TBook;
  EnglishChapter: TChapter;
begin
  if FProject = nil then
    Exit;
  if FSourceRC = nil then
    Exit;
  if (FCurrentChapterIndex < 0) or
     (FCurrentChapterIndex >= FSourceRC.Book.Chapters.Count) then
    Exit;

  { Push any editing memo content back to chunks }
  for I := 0 to Length(FChunkPanels) - 1 do
    FChunkPanels[I].SaveContent;

  SourceChapter := FSourceRC.Book.Chapters[FCurrentChapterIndex];

  { Merge display chunks into single text }
  MergedText := '';
  for I := 0 to Length(FChunkPanels) - 1 do
    MergedText := MergedText + FChunkPanels[I].FTransText;

  if MergedText = '' then
    Exit;

  { Determine save chunking: prefer English ULB, fallback to display source }
  SaveChunkMap := TStringList.Create;
  try
    if FEnglishULBContentDir <> '' then
    begin
      EnglishBook := TBook.Create(FProject.BookCode, 'ulb');
      try
        EnglishBook.LoadFromToc(FEnglishULBContentDir);
        EnglishChapter := EnglishBook.GetChapter(SourceChapter.ID);
        if EnglishChapter <> nil then
        begin
          for I := 0 to EnglishChapter.Chunks.Count - 1 do
            SaveChunkMap.Add(EnglishChapter.Chunks[I].Name);
        end;
      finally
        FreeAndNil(EnglishBook);
      end;
    end;

    { Fallback to source chunking if English ULB not found }
    if SaveChunkMap.Count = 0 then
    begin
      for I := 0 to SourceChapter.Chunks.Count - 1 do
        SaveChunkMap.Add(SourceChapter.Chunks[I].Name);
    end;

    { Split merged text by save chunk map }
    SaveChunks := SourceChapter.SplitByChunkMap(MergedText, SaveChunkMap);
    try
      SaveContentDir := FProject.ProjectDir;
      SaveChapter := TChapter.Create(SourceChapter.ID);
      try
        for I := 0 to SaveChunks.Count - 1 do
        begin
          SaveChapter.AddChunk(TChunk.Create(SaveChunks[I].Name));
          SaveChapter.Chunks[I].Content := SaveChunks[I].Content;
        end;
        SaveChapter.SaveDirtyChunks(SaveContentDir, '.txt');
      finally
        FreeAndNil(SaveChapter);
      end;
    finally
      FreeAndNil(SaveChunks);
    end;
  finally
    FreeAndNil(SaveChunkMap);
  end;
end;

procedure TProjectEditWindow.UpdateStatus;
var
  SourceChapter: TChapter;
  FinCount, I: Integer;
begin
  if (FSourceRC = nil) or (FCurrentChapterIndex < 0) then
    Exit;

  SourceChapter := FSourceRC.Book.Chapters[FCurrentChapterIndex];
  FinCount := 0;
  for I := 0 to SourceChapter.Chunks.Count - 1 do
    if FProject.IsFinished(SourceChapter.ID, SourceChapter.Chunks[I].Name) then
      Inc(FinCount);

  lblStatus.Caption := Format('Chapter %s of %d | %d/%d chunks finished',
    [SourceChapter.ID, FSourceRC.Book.Chapters.Count,
     FinCount, SourceChapter.Chunks.Count]);
end;

procedure TProjectEditWindow.UpdateChapterNav;
begin
  if (FSourceRC = nil) or (FCurrentChapterIndex < 0) then
    Exit;

  lblChapterNum.Caption := FSourceRC.Book.Chapters[FCurrentChapterIndex].ID;
  btnPrevChapter.Enabled := FCurrentChapterIndex > 0;
  btnNextChapter.Enabled := FCurrentChapterIndex < FSourceRC.Book.Chapters.Count - 1;
end;

procedure TProjectEditWindow.OnChunkFinishedChange(Sender: TObject);
var
  CB: TCheckBox;
  I: Integer;
begin
  CB := Sender as TCheckBox;
  if CB.Checked then
  begin
    FProject.MarkFinished(CB.Hint, CB.HelpKeyword);
    { Disable edit for this chunk }
    for I := 0 to Length(FChunkPanels) - 1 do
      if FChunkPanels[I].FFinishedCheck = CB then
      begin
        if FChunkPanels[I].FEditing then
          FChunkPanels[I].SetEditing(False);
        FChunkPanels[I].FEditButton.Enabled := False;
        FChunkPanels[I].FTransDisplay.Font.Color := clGreen;
        FChunkPanels[I].FTransDisplay.Invalidate;
        Break;
      end;
  end
  else
  begin
    FProject.MarkUnfinished(CB.Hint, CB.HelpKeyword);
    for I := 0 to Length(FChunkPanels) - 1 do
      if FChunkPanels[I].FFinishedCheck = CB then
      begin
        FChunkPanels[I].FEditButton.Enabled := True;
        FChunkPanels[I].FTransDisplay.Font.Color := clBlack;
        FChunkPanels[I].FTransDisplay.Invalidate;
        Break;
      end;
  end;
  UpdateStatus;
end;

procedure TProjectEditWindow.OnChunkMemoExit(Sender: TObject);
begin
  SaveCurrentChapter;
  lblStatus.Caption := 'Saved at ' + TimeToStr(Now);
end;

procedure TProjectEditWindow.OnChunkEditClick(Sender: TObject);
var
  Btn: TButton;
  I: Integer;
begin
  Btn := Sender as TButton;
  for I := 0 to Length(FChunkPanels) - 1 do
    if FChunkPanels[I].FEditButton = Btn then
    begin
      FChunkPanels[I].SetEditing(not FChunkPanels[I].FEditing);
      Break;
    end;
end;

{ ---- TChunkPanel ---- }

constructor TChunkPanel.Create(AOwnerForm: TProjectEditWindow;
  ASourceParent, ATransParent: TScrollBox;
  const ASourceText, ATransText, AChapterID, AChunkName, AVerseLabel: string;
  AFinished: Boolean; AProject: TProject; ATopPos: Integer);
var
  PanelHeight, SourceH, TransH: Integer;
  HeaderLabel: TLabel;
begin
  inherited Create;
  FOwnerForm := AOwnerForm;
  FChapterID := AChapterID;
  FChunkName := AChunkName;
  FProject := AProject;
  FEditing := False;
  FTransText := ATransText;

  { Source panel }
  FSourcePanel := TPanel.Create(ASourceParent);
  FSourcePanel.Parent := ASourceParent;
  FSourcePanel.Left := 4;
  FSourcePanel.Top := ATopPos;
  FSourcePanel.Width := ASourceParent.Width - 24;
  FSourcePanel.Anchors := [akTop, akLeft, akRight];
  FSourcePanel.BevelOuter := bvNone;
  FSourcePanel.Color := $F5F5F0;

  { Chunk header label }
  HeaderLabel := TLabel.Create(FSourcePanel);
  HeaderLabel.Parent := FSourcePanel;
  HeaderLabel.Left := 4;
  HeaderLabel.Top := 2;
  HeaderLabel.Caption := AVerseLabel;
  HeaderLabel.Font.Height := -11;
  HeaderLabel.Font.Style := [fsBold];
  HeaderLabel.Font.Color := $808080;

  { Source verse display }
  FSourceDisplay := TVerseDisplay.Create(FSourcePanel);
  FSourceDisplay.Parent := FSourcePanel;
  FSourceDisplay.Left := 0;
  FSourceDisplay.Top := 18;
  FSourceDisplay.Width := FSourcePanel.Width;
  FSourceDisplay.Anchors := [akTop, akLeft, akRight];
  FSourceDisplay.Color := FSourcePanel.Color;
  FSourceDisplay.Font.Height := -13;
  FSourceDisplay.BadgeColor := $D9904A;  { steel blue }
  FSourceDisplay.Text := ASourceText;

  { Calculate source height }
  SourceH := FSourceDisplay.CalcNeededHeight(FSourcePanel.Width) + 20;
  if SourceH < 50 then
    SourceH := 50;
  FSourceDisplay.Height := SourceH - 20;
  FSourcePanel.Height := SourceH;

  { Translation panel }
  FTransPanel := TPanel.Create(ATransParent);
  FTransPanel.Parent := ATransParent;
  FTransPanel.Left := 4;
  FTransPanel.Top := ATopPos;
  FTransPanel.Width := ATransParent.Width - 24;
  FTransPanel.Anchors := [akTop, akLeft, akRight];
  FTransPanel.BevelOuter := bvNone;
  FTransPanel.Color := clWhite;

  { Translation verse display (read-only view) }
  FTransDisplay := TVerseDisplay.Create(FTransPanel);
  FTransDisplay.Parent := FTransPanel;
  FTransDisplay.Left := 0;
  FTransDisplay.Top := 0;
  FTransDisplay.Width := FTransPanel.Width - 80;
  FTransDisplay.Anchors := [akTop, akLeft, akRight];
  FTransDisplay.Color := clWhite;
  FTransDisplay.Font.Height := -13;
  FTransDisplay.BadgeColor := $60AE27;  { green }
  if ATransText <> '' then
    FTransDisplay.Text := ATransText
  else
  begin
    FTransDisplay.Text := '';
    FTransDisplay.Font.Color := clGray;
  end;

  { Calculate translation height }
  if ATransText <> '' then
    TransH := FTransDisplay.CalcNeededHeight(FTransPanel.Width - 80)
  else
    TransH := 30;
  if TransH < 30 then
    TransH := 30;
  FTransDisplay.Height := TransH;

  { Use the taller of source/trans for both panels }
  PanelHeight := SourceH;
  if TransH + 4 > PanelHeight then
    PanelHeight := TransH + 4;
  FSourcePanel.Height := PanelHeight;
  FSourceDisplay.Height := PanelHeight - 20;
  FTransPanel.Height := PanelHeight;
  FTransDisplay.Height := PanelHeight;

  { Edit memo (hidden initially) }
  FTransMemo := TMemo.Create(FTransPanel);
  FTransMemo.Parent := FTransPanel;
  FTransMemo.Left := 0;
  FTransMemo.Top := 0;
  FTransMemo.Width := FTransPanel.Width - 80;
  FTransMemo.Height := PanelHeight;
  FTransMemo.Anchors := [akTop, akLeft, akRight, akBottom];
  FTransMemo.Text := ATransText;
  FTransMemo.Font.Height := -13;
  FTransMemo.ScrollBars := ssAutoVertical;
  FTransMemo.Visible := False;
  FTransMemo.OnExit := @AOwnerForm.OnChunkMemoExit;

  { Edit button }
  FEditButton := TButton.Create(FTransPanel);
  FEditButton.Parent := FTransPanel;
  FEditButton.Width := 50;
  FEditButton.Height := 26;
  FEditButton.Left := FTransPanel.Width - 70;
  FEditButton.Top := 4;
  FEditButton.Anchors := [akTop, akRight];
  FEditButton.Caption := 'Edit';
  FEditButton.OnClick := @AOwnerForm.OnChunkEditClick;

  { Finished checkbox }
  FFinishedCheck := TCheckBox.Create(FTransPanel);
  FFinishedCheck.Parent := FTransPanel;
  FFinishedCheck.Width := 60;
  FFinishedCheck.Height := 20;
  FFinishedCheck.Left := FTransPanel.Width - 70;
  FFinishedCheck.Top := 34;
  FFinishedCheck.Anchors := [akTop, akRight];
  FFinishedCheck.Caption := 'Done';
  FFinishedCheck.Checked := AFinished;
  FFinishedCheck.Hint := AChapterID;
  FFinishedCheck.HelpKeyword := AChunkName;
  FFinishedCheck.OnChange := @AOwnerForm.OnChunkFinishedChange;

  { If finished, disable editing and use green text }
  if AFinished then
  begin
    FEditButton.Enabled := False;
    FTransDisplay.Font.Color := clGreen;
    FTransDisplay.Invalidate;
  end;
end;

destructor TChunkPanel.Destroy;
begin
  FreeAndNil(FSourcePanel);
  FreeAndNil(FTransPanel);
  inherited Destroy;
end;

procedure TChunkPanel.SetEditing(AEdit: Boolean);
begin
  if FFinishedCheck.Checked and AEdit then
    Exit;

  FEditing := AEdit;
  FTransDisplay.Visible := not AEdit;
  FTransMemo.Visible := AEdit;

  if AEdit then
  begin
    FTransMemo.Text := FTransText;
    FEditButton.Caption := 'Save';
    FTransPanel.Color := $F0FFFF;  { light yellow }
    FTransMemo.Color := $F0FFFF;
    FTransMemo.SetFocus;
  end
  else
  begin
    SaveContent;
    FEditButton.Caption := 'Edit';
    FTransPanel.Color := clWhite;
    FTransDisplay.Color := clWhite;
  end;
end;

procedure TChunkPanel.SaveContent;
begin
  if FEditing then
  begin
    FTransText := FTransMemo.Text;
    FTransDisplay.Text := FTransText;
    if FTransText <> '' then
      FTransDisplay.Font.Color := clBlack
    else
      FTransDisplay.Font.Color := clGray;
  end;
end;

function TChunkPanel.GetHeight: Integer;
begin
  Result := FSourcePanel.Height;
end;

end.
