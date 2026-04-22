{$mode objfpc}{$H+}
unit GameViewChunkEdit;

{ Full-screen chunk text editor — Phase 5.

  Usage (from a parent view):
    ViewChunkEdit.InputText := chunk.Content;
    Container.PushView(ViewChunkEdit);

  Parent's Resume:
    if ViewChunkEdit.Answered and not ViewChunkEdit.Cancelled then
      chunk.Content := ViewChunkEdit.Answer;

  Editor state:
    FLines     — TStringList buffer (one entry per logical line)
    FCursorLine, FCursorCol — 0-based cursor position

  Keyboard:
    printable chars       insert at cursor
    Enter                 split line
    Backspace / Delete    delete back / forward, merge lines
    Arrow keys            move cursor
    Home / End            start / end of line
    Ctrl+V                paste clipboard (multiline-safe)
    Ctrl+C                copy all to clipboard

  Display:
    Single TCastleLabel (Html=False) with '|' injected at cursor.
    Rebuilt in Update once per FNeedsRedraw flag.
}

interface

uses
  Classes,
  CastleUIControls, CastleControls, CastleColors, CastleKeysMouse,
  CGEViewBase, BTTHeader;

type
  TViewChunkEdit = class(TCGEViewBase)
  private
    { ── data ── }
    FInputText   : string;
    FLines       : TStringList;
    FCursorLine  : Integer;
    FCursorCol   : Integer;
    FAnswer      : string;
    FAnswered    : Boolean;
    FCancelled   : Boolean;

    { ── chrome ── }
    FHeader      : TBTTHeader;
    FScrollView  : TCastleScrollView;
    FContentLbl  : TCastleLabel;
    FNeedsRedraw : Boolean;

    procedure BuildChrome;
    procedure RebuildLabel;
    procedure ClampCursor;
    procedure InsertText(const S: string);

    procedure ClickCancel(Sender: TObject);
    procedure ClickSave(Sender: TObject);
  public
    procedure Start;  override;
    procedure Stop;   override;
    procedure Resize; override;
    procedure Update(const SecondsPassed: Single; var HandleInput: Boolean); override;
    function  Press(const Event: TInputPressRelease): Boolean; override;
    procedure OnThemeChange; override;

    { Set before pushing the view. }
    property InputText: string  read FInputText  write FInputText;

    { Read in parent's Resume after the view pops. }
    property Answer:   string  read FAnswer;
    property Answered: Boolean read FAnswered;
    property Cancelled: Boolean read FCancelled;
  end;

var
  ViewChunkEdit: TViewChunkEdit;

implementation

uses
  SysUtils, Math, CastleVectors,
  AppState, BTTTheme, AppLog;

const
  ContentPad = 16;

{ ── TViewChunkEdit ────────────────────────────────────────────────────────── }

procedure TViewChunkEdit.Start;
begin
  inherited;
  ApplyBackground;
  InterceptInput := True;

  FLines := TStringList.Create;
  FLines.Text := FInputText;
  { TStringList.Text always adds a trailing line ending; strip blank tail lines. }
  while (FLines.Count > 0) and (FLines[FLines.Count - 1] = '') do
    FLines.Delete(FLines.Count - 1);
  if FLines.Count = 0 then
    FLines.Add('');

  FCursorLine := FLines.Count - 1;
  FCursorCol  := Length(FLines[FCursorLine]);
  FAnswered   := False;
  FCancelled  := False;
  FAnswer     := '';

  BuildChrome;
  FNeedsRedraw := True;
end;

procedure TViewChunkEdit.Stop;
begin
  FreeAndNil(FLines);
  inherited;
end;

procedure TViewChunkEdit.BuildChrome;
var
  Pal       : TBTTPalette;
  CancelBtn : TCastleButton;
  SaveBtn   : TCastleButton;
begin
  Pal := P;

  FHeader := TBTTHeader.Create(FreeAtStop, Pal);
  FHeader.SetTitle('Edit Chunk');
  InsertFront(FHeader);

  CancelBtn          := TCastleButton.Create(FreeAtStop);
  CancelBtn.Caption  := 'Cancel';
  CancelBtn.FontSize := 14;
  CancelBtn.OnClick  := @ClickCancel;
  FHeader.AddLeft(CancelBtn);

  SaveBtn          := TCastleButton.Create(FreeAtStop);
  SaveBtn.Caption  := 'Save';
  SaveBtn.FontSize := 14;
  SaveBtn.OnClick  := @ClickSave;
  FHeader.AddRight(SaveBtn);

  FScrollView := TCastleScrollView.Create(FreeAtStop);
  InsertFront(FScrollView);

  FContentLbl             := TCastleLabel.Create(FreeAtStop);
  FContentLbl.Html        := False;
  FContentLbl.Color       := Pal.TextPrimary;
  FContentLbl.FontSize    := 15;
  FContentLbl.Translation := Vector2(ContentPad, ContentPad);
  FScrollView.ScrollArea.InsertFront(FContentLbl);
end;

procedure TViewChunkEdit.ClampCursor;
begin
  if FLines.Count = 0 then
  begin
    FLines.Add('');
    FCursorLine := 0;
    FCursorCol  := 0;
    Exit;
  end;
  if FCursorLine < 0 then FCursorLine := 0;
  if FCursorLine >= FLines.Count then FCursorLine := FLines.Count - 1;
  if FCursorCol < 0 then FCursorCol := 0;
  if FCursorCol > Length(FLines[FCursorLine]) then
    FCursorCol := Length(FLines[FCursorLine]);
end;

procedure TViewChunkEdit.RebuildLabel;
var
  I    : Integer;
  S, L : string;
begin
  if FContentLbl = nil then Exit;
  S := '';
  for I := 0 to FLines.Count - 1 do
  begin
    if I = FCursorLine then
    begin
      ClampCursor;
      L := Copy(FLines[I], 1, FCursorCol) + '|' +
           Copy(FLines[I], FCursorCol + 1, MaxInt);
    end
    else
      L := FLines[I];
    if I > 0 then S := S + LineEnding;
    S := S + L;
  end;
  FContentLbl.Caption := S;

  { Resize scroll area to fit the label. }
  FScrollView.ScrollArea.Width  := FScrollView.EffectiveWidthForChildren;
  FScrollView.ScrollArea.Height :=
    Max(FScrollView.Height,
        FContentLbl.EffectiveHeight + ContentPad * 2);
end;

procedure TViewChunkEdit.InsertText(const S: string);
var
  Before, After : string;
  NewLines      : TStringList;
  I             : Integer;
begin
  if S = '' then Exit;
  ClampCursor;
  Before := Copy(FLines[FCursorLine], 1, FCursorCol);
  After  := Copy(FLines[FCursorLine], FCursorCol + 1, MaxInt);

  if (Pos(#10, S) > 0) or (Pos(#13, S) > 0) then
  begin
    { Multiline paste — normalize line endings, split into lines. }
    NewLines := TStringList.Create;
    try
      NewLines.Text := S;
      while (NewLines.Count > 0) and (NewLines[NewLines.Count - 1] = '') do
        NewLines.Delete(NewLines.Count - 1);
      if NewLines.Count = 0 then Exit;

      FLines[FCursorLine] := Before + NewLines[0];
      for I := 1 to NewLines.Count - 1 do
        FLines.Insert(FCursorLine + I, NewLines[I]);

      FCursorLine := FCursorLine + NewLines.Count - 1;
      FLines[FCursorLine] := FLines[FCursorLine] + After;
      FCursorCol  := Length(FLines[FCursorLine]) - Length(After);
    finally
      NewLines.Free;
    end;
  end
  else
  begin
    FLines[FCursorLine] := Before + S + After;
    Inc(FCursorCol, Length(S));
  end;
end;

function TViewChunkEdit.Press(const Event: TInputPressRelease): Boolean;
var
  Line, Before, After, PrevLine : string;
begin
  Result := inherited;
  if Event.EventType <> itKey then Exit;

  { Backspace }
  if Event.IsKey(keyBackSpace) then
  begin
    ClampCursor;
    Line := FLines[FCursorLine];
    if FCursorCol > 0 then
    begin
      FLines[FCursorLine] :=
        Copy(Line, 1, FCursorCol - 1) + Copy(Line, FCursorCol + 1, MaxInt);
      Dec(FCursorCol);
    end
    else if FCursorLine > 0 then
    begin
      PrevLine   := FLines[FCursorLine - 1];
      FCursorCol := Length(PrevLine);
      FLines[FCursorLine - 1] := PrevLine + Line;
      FLines.Delete(FCursorLine);
      Dec(FCursorLine);
    end;
    FNeedsRedraw := True;
    Result := True;
    Exit;
  end;

  { Delete }
  if Event.IsKey(keyDelete) then
  begin
    ClampCursor;
    Line := FLines[FCursorLine];
    if FCursorCol < Length(Line) then
      FLines[FCursorLine] :=
        Copy(Line, 1, FCursorCol) + Copy(Line, FCursorCol + 2, MaxInt)
    else if FCursorLine < FLines.Count - 1 then
    begin
      FLines[FCursorLine] := Line + FLines[FCursorLine + 1];
      FLines.Delete(FCursorLine + 1);
    end;
    FNeedsRedraw := True;
    Result := True;
    Exit;
  end;

  { Enter — split line at cursor }
  if Event.IsKey(keyEnter) then
  begin
    ClampCursor;
    Before := Copy(FLines[FCursorLine], 1, FCursorCol);
    After  := Copy(FLines[FCursorLine], FCursorCol + 1, MaxInt);
    FLines[FCursorLine] := Before;
    FLines.Insert(FCursorLine + 1, After);
    Inc(FCursorLine);
    FCursorCol   := 0;
    FNeedsRedraw := True;
    Result := True;
    Exit;
  end;

  { Arrow keys }
  if Event.IsKey(keyArrowLeft) then
  begin
    ClampCursor;
    if FCursorCol > 0 then
      Dec(FCursorCol)
    else if FCursorLine > 0 then
    begin
      Dec(FCursorLine);
      FCursorCol := Length(FLines[FCursorLine]);
    end;
    FNeedsRedraw := True;
    Result := True;
    Exit;
  end;

  if Event.IsKey(keyArrowRight) then
  begin
    ClampCursor;
    if FCursorCol < Length(FLines[FCursorLine]) then
      Inc(FCursorCol)
    else if FCursorLine < FLines.Count - 1 then
    begin
      Inc(FCursorLine);
      FCursorCol := 0;
    end;
    FNeedsRedraw := True;
    Result := True;
    Exit;
  end;

  if Event.IsKey(keyArrowUp) then
  begin
    if FCursorLine > 0 then
    begin
      Dec(FCursorLine);
      ClampCursor;
    end;
    FNeedsRedraw := True;
    Result := True;
    Exit;
  end;

  if Event.IsKey(keyArrowDown) then
  begin
    if FCursorLine < FLines.Count - 1 then
    begin
      Inc(FCursorLine);
      ClampCursor;
    end;
    FNeedsRedraw := True;
    Result := True;
    Exit;
  end;

  { Home / End }
  if Event.IsKey(keyHome) then
  begin
    FCursorCol   := 0;
    FNeedsRedraw := True;
    Result := True;
    Exit;
  end;

  if Event.IsKey(keyEnd) then
  begin
    ClampCursor;
    FCursorCol   := Length(FLines[FCursorLine]);
    FNeedsRedraw := True;
    Result := True;
    Exit;
  end;

  { Ctrl+C — copy all }
  if Event.IsKey(keyC, [mkCtrl]) then
  begin
    Clipboard.AsText := FLines.Text;
    Result := True;
    Exit;
  end;

  { Ctrl+V — paste }
  if Event.IsKey(keyV, [mkCtrl]) then
  begin
    InsertText(Clipboard.AsText);
    FNeedsRedraw := True;
    Result := True;
    Exit;
  end;

  { Printable characters — skip control chars (#0..#31) }
  if (Event.KeyString <> '') and
     (Ord(Event.KeyString[1]) > 31) then
  begin
    InsertText(Event.KeyString);
    FNeedsRedraw := True;
    Result := True;
    Exit;
  end;
end;

procedure TViewChunkEdit.ClickCancel(Sender: TObject);
begin
  FAnswered  := True;
  FCancelled := True;
  Container.PopView(Self);
end;

procedure TViewChunkEdit.ClickSave(Sender: TObject);
var
  I : Integer;
begin
  FAnswer := '';
  for I := 0 to FLines.Count - 1 do
  begin
    if I > 0 then FAnswer := FAnswer + LineEnding;
    FAnswer := FAnswer + FLines[I];
  end;
  FAnswered  := True;
  FCancelled := False;
  Container.PopView(Self);
end;

procedure TViewChunkEdit.Resize;
var
  W, H : Single;
begin
  inherited;
  if FHeader = nil then Exit;
  W := EffectiveWidth;
  H := EffectiveHeight;

  FHeader.Translation := Vector2(0, H - BTT_HEADER_H);
  FHeader.Width       := W;
  FHeader.Height      := BTT_HEADER_H;

  FScrollView.Translation := Vector2(0, 0);
  FScrollView.Width       := W;
  FScrollView.Height      := H - BTT_HEADER_H;

  FContentLbl.MaxWidth := W - ContentPad * 2;
  FNeedsRedraw := True;
end;

procedure TViewChunkEdit.Update(const SecondsPassed: Single;
  var HandleInput: Boolean);
begin
  inherited;
  if FNeedsRedraw then
  begin
    FNeedsRedraw := False;
    RebuildLabel;
  end;
end;

procedure TViewChunkEdit.OnThemeChange;
begin
  if Container <> nil then
    Container.View := Self;
end;

end.
