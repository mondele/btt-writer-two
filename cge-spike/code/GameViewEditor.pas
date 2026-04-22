{$mode objfpc}{$H+}
unit GameViewEditor;

{ Editor view.  Proves three things:
    1. State-driven layout: GAppState drives what is shown.
    2. USFM verse text rendered via CGE TCastleLabel with HTML tags.
    3. Click-to-edit state transition: chunk index stored in GAppState,
       panel swaps to edit placeholder.  This is the insertion point for
       the native GTK text overlay (Phase 5). }

interface

uses
  Classes,
  CastleUIControls, CastleControls, CastleColors, CastleKeysMouse;

const
  HeaderH      = 60;
  SidebarW     = 80;
  ChunkGap     = 12;
  PanelPad     = 14;
  ChunkHeaderH = 34;
  ChunkFooterH = 38;
  ChunkTextH   = 140; { fixed for spike; dynamic sizing is Phase 4 work }
  ChunkH       = ChunkHeaderH + ChunkTextH + ChunkFooterH;

type
  { Visual representation of one translation chunk.
    Holds display (verse text) and edit (placeholder) layers,
    toggled via GAppState.EditingChunkIndex. }
  TChunkPanel = class(TCastleUserInterface)
  private
    FIndex          : Integer;
    FVerseRange     : String;
    FVerseHtml      : String;
    FBg             : TCastleRectangleControl;
    FChunkHdr       : TCastleRectangleControl;
    FRangeLbl       : TCastleLabel;
    FVerseLbl       : TCastleLabel;
    FEditPlaceholder: TCastleRectangleControl;
    FEditHint       : TCastleLabel;
    FEditBtn        : TCastleButton;
    FDoneBtn        : TCastleButton;
    procedure ClickEdit(Sender: TObject);
    procedure ClickDone(Sender: TObject);
    procedure UpdateEditState;
  public
    constructor Create(AOwner: TComponent;
      AIndex: Integer;
      const AVerseRange, AVerseHtml: String); reintroduce;
    procedure RefreshState;
    procedure SetVerseMaxWidth(const W: Single);
  end;

  TViewEditor = class(TCastleView)
  private
    FHeader    : TCastleRectangleControl;
    FTitleLbl  : TCastleLabel;
    FBackBtn   : TCastleButton;
    FSidebar   : TCastleRectangleControl;
    FScrollView: TCastleScrollView;
    FChunks    : array[0..2] of TChunkPanel;

    procedure ClickBack(Sender: TObject);
    procedure BuildUI;
    procedure UpdateScrollArea;
  public
    procedure Start; override;
    procedure Resize; override;
  end;

var
  ViewEditor: TViewEditor;

implementation

uses
  SysUtils,
  CastleVectors,
  AppState, GameViewHome;

{ Sample Psalm 23 chunk data.
  Verse markers rendered as small gray inline numbers via HTML. }
const
  Psalm23_Range: array[0..2] of String = (
    'Psalm 23:1-3',
    'Psalm 23:4',
    'Psalm 23:5-6'
  );
  Psalm23_Html: array[0..2] of String = (
    '<font color="#9E9E9E"><b>1</b></font>  The LORD is my shepherd; I shall not want.' +
    '<br><font color="#9E9E9E"><b>2</b></font>  He maketh me to lie down in green pastures: ' +
    'he leadeth me beside the still waters.' +
    '<br><font color="#9E9E9E"><b>3</b></font>  He restoreth my soul: he leadeth me in the paths ' +
    'of righteousness for his name''s sake.',

    '<font color="#9E9E9E"><b>4</b></font>  Yea, though I walk through the valley of the shadow ' +
    'of death, I will fear no evil: for thou art with me; ' +
    'thy rod and thy staff they comfort me.',

    '<font color="#9E9E9E"><b>5</b></font>  Thou preparest a table before me in the presence of ' +
    'mine enemies: thou anointest my head with oil; my cup runneth over.' +
    '<br><font color="#9E9E9E"><b>6</b></font>  Surely goodness and mercy shall follow me all the ' +
    'days of my life: and I will dwell in the house of the LORD for ever.'
  );

{ TChunkPanel }

constructor TChunkPanel.Create(AOwner: TComponent;
  AIndex: Integer; const AVerseRange, AVerseHtml: String);
var
  FInner: TCastleRectangleControl;
begin
  inherited Create(AOwner);
  FIndex      := AIndex;
  FVerseRange := AVerseRange;
  FVerseHtml  := AVerseHtml;

  { Light gray border via outer rect }
  FBg := TCastleRectangleControl.Create(AOwner);
  FBg.Color := HexToColor('E0E0E0');
  FBg.FullSize := true;
  InsertFront(FBg);

  { Inner white area — 2px inset gives the border effect }
  FInner := TCastleRectangleControl.Create(AOwner);
  FInner.Color := White;
  FInner.Anchor(hpLeft,   hpLeft,   2);
  FInner.Anchor(hpRight,  hpRight, -2);
  FInner.Anchor(vpTop,    vpTop,   -2);
  FInner.Anchor(vpBottom, vpBottom, 2);
  InsertFront(FInner);

  { Chunk header strip }
  FChunkHdr := TCastleRectangleControl.Create(AOwner);
  FChunkHdr.Color := HexToColor('F5F5F5');
  FChunkHdr.Height := ChunkHeaderH;
  FChunkHdr.WidthFraction := 1;
  FChunkHdr.Anchor(vpTop, vpTop);
  InsertFront(FChunkHdr);

  FRangeLbl := TCastleLabel.Create(AOwner);
  FRangeLbl.Caption := FVerseRange;
  FRangeLbl.Color := HexToColor('424242');
  FRangeLbl.FontSize := 13;
  FRangeLbl.Anchor(hpLeft, hpLeft, PanelPad);
  FRangeLbl.Anchor(vpMiddle, vpMiddle);
  FChunkHdr.InsertFront(FRangeLbl);

  { Verse text label (HTML-formatted, word-wrapped) }
  FVerseLbl := TCastleLabel.Create(AOwner);
  FVerseLbl.Caption := FVerseHtml;
  FVerseLbl.Html := true;
  FVerseLbl.Color := HexToColor('212121');
  FVerseLbl.FontSize := 15;
  FVerseLbl.Anchor(hpLeft, hpLeft, PanelPad);
  FVerseLbl.Anchor(vpTop, vpTop, -(ChunkHeaderH + PanelPad));
  InsertFront(FVerseLbl);

  { Edit placeholder shown in place of verse text while editing.
    Phase 5: replace this rect with the native OS text widget overlay. }
  FEditPlaceholder := TCastleRectangleControl.Create(AOwner);
  FEditPlaceholder.Color := HexToColor('FFFDE7');
  FEditPlaceholder.WidthFraction := 1;
  FEditPlaceholder.Height := ChunkTextH;
  FEditPlaceholder.Anchor(vpTop, vpTop, -ChunkHeaderH);
  FEditPlaceholder.Exists := false;
  InsertFront(FEditPlaceholder);

  FEditHint := TCastleLabel.Create(AOwner);
  FEditHint.Caption :=
    '[ Native OS text widget overlay here ]' + LineEnding +
    'GTK GtkTextView / Win32 HWND Edit / UITextView';
  FEditHint.Color := HexToColor('F57F17');
  FEditHint.FontSize := 13;
  FEditHint.Alignment := hpMiddle;
  FEditHint.Anchor(hpMiddle, hpMiddle);
  FEditHint.Anchor(vpMiddle, vpMiddle);
  FEditPlaceholder.InsertFront(FEditHint);

  { Footer buttons }
  FEditBtn := TCastleButton.Create(AOwner);
  FEditBtn.Caption := 'Edit';
  FEditBtn.FontSize := 13;
  FEditBtn.OnClick := @ClickEdit;
  FEditBtn.Anchor(hpRight, hpRight, -PanelPad);
  FEditBtn.Anchor(vpBottom, vpBottom, PanelPad - 2);
  InsertFront(FEditBtn);

  FDoneBtn := TCastleButton.Create(AOwner);
  FDoneBtn.Caption := 'Done';
  FDoneBtn.FontSize := 13;
  FDoneBtn.OnClick := @ClickDone;
  FDoneBtn.Anchor(hpRight, hpRight, -PanelPad);
  FDoneBtn.Anchor(vpBottom, vpBottom, PanelPad - 2);
  FDoneBtn.Exists := false;
  InsertFront(FDoneBtn);

  Height := ChunkH;
end;

procedure TChunkPanel.ClickEdit(Sender: TObject);
begin
  GAppState.EditingChunkIndex := FIndex;
  UpdateEditState;
end;

procedure TChunkPanel.ClickDone(Sender: TObject);
begin
  GAppState.EditingChunkIndex := -1;
  UpdateEditState;
end;

procedure TChunkPanel.RefreshState;
begin
  UpdateEditState;
end;

procedure TChunkPanel.UpdateEditState;
var
  Editing: Boolean;
begin
  Editing := (GAppState.EditingChunkIndex = FIndex);
  FVerseLbl.Exists        := not Editing;
  FEditPlaceholder.Exists := Editing;
  FEditBtn.Exists         := not Editing;
  FDoneBtn.Exists         := Editing;
end;

procedure TChunkPanel.SetVerseMaxWidth(const W: Single);
begin
  FVerseLbl.MaxWidth := W - PanelPad * 2;
end;

{ TViewEditor }

procedure TViewEditor.Start;
begin
  inherited;
  BuildUI;
end;

procedure TViewEditor.BuildUI;
var
  I      : Integer;
  FBg    : TCastleRectangleControl;
  ChLabel: TCastleLabel;
begin
  { White background }
  FBg := TCastleRectangleControl.Create(FreeAtStop);
  FBg.Color := White;
  FBg.FullSize := true;
  InsertFront(FBg);

  { Header bar }
  FHeader := TCastleRectangleControl.Create(FreeAtStop);
  FHeader.Color := HexToColor('1565C0');
  FHeader.Height := HeaderH;
  FHeader.WidthFraction := 1;
  FHeader.Anchor(vpTop, vpTop);
  FHeader.Anchor(hpLeft, hpLeft);
  InsertFront(FHeader);

  FBackBtn := TCastleButton.Create(FreeAtStop);
  FBackBtn.Caption := '< Home';
  FBackBtn.FontSize := 14;
  FBackBtn.OnClick := @ClickBack;
  FBackBtn.Anchor(hpLeft, hpLeft, 12);
  FBackBtn.Anchor(vpMiddle, vpMiddle);
  FHeader.InsertFront(FBackBtn);

  FTitleLbl := TCastleLabel.Create(FreeAtStop);
  FTitleLbl.Caption := GAppState.ProjectTitle;
  FTitleLbl.Color := White;
  FTitleLbl.FontSize := 18;
  FTitleLbl.Anchor(hpMiddle, hpMiddle);
  FTitleLbl.Anchor(vpMiddle, vpMiddle);
  FHeader.InsertFront(FTitleLbl);

  { Left sidebar — sized explicitly in Resize }
  FSidebar := TCastleRectangleControl.Create(FreeAtStop);
  FSidebar.Color := HexToColor('1976D2');
  InsertFront(FSidebar);

  ChLabel := TCastleLabel.Create(FreeAtStop);
  ChLabel.Caption := 'Ch.' + LineEnding + IntToStr(GAppState.ChapterNum);
  ChLabel.Color := White;
  ChLabel.FontSize := 14;
  ChLabel.Alignment := hpMiddle;
  ChLabel.Anchor(hpMiddle, hpMiddle);
  ChLabel.Anchor(vpTop, vpTop, -30);
  FSidebar.InsertFront(ChLabel);

  { ScrollView — sized explicitly in Resize }
  FScrollView := TCastleScrollView.Create(FreeAtStop);
  InsertFront(FScrollView);

  for I := 0 to 2 do
  begin
    FChunks[I] := TChunkPanel.Create(FreeAtStop, I,
      Psalm23_Range[I], Psalm23_Html[I]);
    FScrollView.ScrollArea.InsertFront(FChunks[I]);
  end;
end;

procedure TViewEditor.ClickBack(Sender: TObject);
begin
  GAppState.Screen := asHome;
  GAppState.EditingChunkIndex := -1;
  Container.View := ViewHome;
end;

procedure TViewEditor.Resize;
var
  W, H, ContentH: Single;
begin
  inherited;
  if FScrollView = nil then Exit;

  W := EffectiveWidth;
  H := EffectiveHeight;
  ContentH := H - HeaderH;

  { Header already has WidthFraction=1 and Anchor(vpTop,vpTop) — no change needed }

  { Sidebar: full height below header, fixed width }
  FSidebar.Translation := Vector2(0, 0);
  FSidebar.Width  := SidebarW;
  FSidebar.Height := ContentH;

  { ScrollView: right of sidebar, same height }
  FScrollView.Translation := Vector2(SidebarW, 0);
  FScrollView.Width  := W - SidebarW;
  FScrollView.Height := ContentH;

  UpdateScrollArea;
end;

procedure TViewEditor.UpdateScrollArea;
var
  I        : Integer;
  AreaW    : Single;
  TotalH   : Single;
  CurBottom: Single;
begin
  AreaW := FScrollView.EffectiveWidthForChildren
         - FScrollView.EffectiveScrollBarWidth;

  TotalH := ChunkGap;
  for I := 0 to 2 do
    TotalH := TotalH + ChunkH + ChunkGap;

  FScrollView.ScrollArea.Width  := AreaW;
  FScrollView.ScrollArea.Height := TotalH;

  { Lay out panels top-to-bottom.
    CGE coordinate origin is bottom-left, so the topmost chunk has the
    largest Y (Bottom) value. }
  CurBottom := TotalH - ChunkGap;
  for I := 0 to 2 do
  begin
    CurBottom := CurBottom - ChunkH;
    FChunks[I].Translation := Vector2(ChunkGap, CurBottom);
    FChunks[I].Width := AreaW - ChunkGap * 2;
    FChunks[I].SetVerseMaxWidth(FChunks[I].Width);
    CurBottom := CurBottom - ChunkGap;
  end;
end;

end.
