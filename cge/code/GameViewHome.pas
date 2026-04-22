{$mode objfpc}{$H+}
unit GameViewHome;

{ Home screen.
  Scans for real projects via ProjectScanner and displays them in a
  scrollable list.  Tapping a row stores the project in GAppState and
  navigates to the editor view. }

interface

uses
  Classes,
  CastleUIControls, CastleControls, CastleColors, CastleVectors,
  CGEViewBase,
  ProjectScanner;

type
  TViewHome = class(TCGEViewBase)
  private
    FHeader     : TCastleRectangleControl;
    FTitleLbl   : TCastleLabel;
    FUserLbl    : TCastleLabel;
    FScrollView : TCastleScrollView;
    FProjects   : TProjectSummaryList;

    procedure BuildHeader;
    procedure BuildProjectList;
    procedure UpdateScrollArea;
    procedure ClickProject(Sender: TObject);
  public
    procedure Start; override;
    procedure Resize; override;
    procedure OnThemeChange; override;
  end;

var
  ViewHome: TViewHome;

implementation

uses
  SysUtils,
  CastleKeysMouse,
  AppState, BTTTheme,
  GameViewEditor;

const
  HeaderH  = 60;
  RowH     = 72;
  RowGap   = 2;
  RowPad   = 16;

{ TViewHome }

procedure TViewHome.Start;
begin
  inherited;
  ApplyBackground;
  FProjects := ScanProjects;
  BuildHeader;
  BuildProjectList;
end;

procedure TViewHome.BuildHeader;
var
  Pal: TBTTPalette;
begin
  Pal := P;

  FHeader := TCastleRectangleControl.Create(FreeAtStop);
  FHeader.Color := Pal.HeaderBg;
  FHeader.Height := HeaderH;
  FHeader.WidthFraction := 1;
  FHeader.Anchor(vpTop, vpTop);
  InsertFront(FHeader);

  FTitleLbl := TCastleLabel.Create(FreeAtStop);
  FTitleLbl.Caption := 'BTT-Writer';
  FTitleLbl.Color := Pal.HeaderText;
  FTitleLbl.FontSize := 22;
  FTitleLbl.Anchor(hpMiddle, hpMiddle);
  FTitleLbl.Anchor(vpMiddle, vpMiddle);
  FHeader.InsertFront(FTitleLbl);

  FUserLbl := TCastleLabel.Create(FreeAtStop);
  FUserLbl.Caption := GAppState.UserName;
  FUserLbl.Color := Pal.TextInverse;
  FUserLbl.FontSize := 13;
  FUserLbl.Anchor(hpRight, hpRight, -RowPad);
  FUserLbl.Anchor(vpMiddle, vpMiddle);
  FHeader.InsertFront(FUserLbl);
end;

procedure TViewHome.BuildProjectList;
var
  I: Integer;
  Row: TCastleRectangleControl;
  NameLbl, DetailLbl: TCastleLabel;
  EmptyLbl: TCastleLabel;
  Btn: TCastleButton;
  Pal: TBTTPalette;
begin
  Pal := P;

  FScrollView := TCastleScrollView.Create(FreeAtStop);
  InsertFront(FScrollView);

  if Length(FProjects) = 0 then
  begin
    { Empty-state label }
    EmptyLbl := TCastleLabel.Create(FreeAtStop);
    EmptyLbl.Caption :=
      'No translation projects found.' + LineEnding +
      'Projects are stored in:' + LineEnding +
      '~/.config/BTT-Writer/targetTranslations/';
    EmptyLbl.Color := Pal.TextSecondary;
    EmptyLbl.FontSize := 15;
    EmptyLbl.Alignment := hpMiddle;
    EmptyLbl.Anchor(hpMiddle, hpMiddle);
    EmptyLbl.Anchor(vpMiddle, vpMiddle);
    FScrollView.ScrollArea.InsertFront(EmptyLbl);
    Exit;
  end;

  for I := 0 to High(FProjects) do
  begin
    Row := TCastleRectangleControl.Create(FreeAtStop);
    Row.Color := Pal.PanelBg;
    Row.Height := RowH;
    Row.Tag := I;
    FScrollView.ScrollArea.InsertFront(Row);

    NameLbl := TCastleLabel.Create(FreeAtStop);
    NameLbl.Caption := FProjects[I].BookName + '  (' + FProjects[I].TargetLangCode + ')';
    NameLbl.Color := Pal.TextPrimary;
    NameLbl.FontSize := 16;
    NameLbl.Anchor(hpLeft, hpLeft, RowPad);
    NameLbl.Anchor(vpTop, vpTop, -14);
    Row.InsertFront(NameLbl);

    DetailLbl := TCastleLabel.Create(FreeAtStop);
    DetailLbl.Caption :=
      FProjects[I].ResourceType + '  •  ' +
      IntToStr(FProjects[I].FinishedChunks) + ' / ' +
      IntToStr(FProjects[I].TotalChunks) + ' chunks';
    DetailLbl.Color := Pal.TextSecondary;
    DetailLbl.FontSize := 13;
    DetailLbl.Anchor(hpLeft, hpLeft, RowPad);
    DetailLbl.Anchor(vpBottom, vpBottom, 14);
    Row.InsertFront(DetailLbl);

    Btn := TCastleButton.Create(FreeAtStop);
    Btn.Caption := 'Open';
    Btn.FontSize := 13;
    Btn.Tag := I;
    Btn.OnClick := @ClickProject;
    Btn.Anchor(hpRight, hpRight, -RowPad);
    Btn.Anchor(vpMiddle, vpMiddle);
    Row.InsertFront(Btn);
  end;
end;

procedure TViewHome.ClickProject(Sender: TObject);
var
  I: Integer;
begin
  I := (Sender as TCastleButton).Tag;
  if (I < 0) or (I > High(FProjects)) then Exit;

  GAppState.Screen              := asEditor;
  GAppState.Editor.ProjectDir   := FProjects[I].FullPath;
  GAppState.Editor.ProjectTitle :=
    FProjects[I].BookName + ' — ' + FProjects[I].TargetLangCode;
  GAppState.Editor.BookCode     := FProjects[I].BookCode;
  GAppState.Editor.TargetLangCode := FProjects[I].TargetLangCode;
  GAppState.Editor.ChapterIndex := 0;
  GAppState.Editor.ChunkIndex   := -1;

  Container.View := ViewEditor;
end;

procedure TViewHome.Resize;
var
  W, H: Single;
begin
  inherited;
  if FScrollView = nil then Exit;
  W := EffectiveWidth;
  H := EffectiveHeight;
  FScrollView.Translation := Vector2(0, 0);
  FScrollView.Width  := W;
  FScrollView.Height := H - HeaderH;
  UpdateScrollArea;
end;

procedure TViewHome.UpdateScrollArea;
var
  I: Integer;
  AreaW, TotalH, CurBottom: Single;
  Row: TCastleUserInterface;
begin
  AreaW := FScrollView.EffectiveWidthForChildren
         - FScrollView.EffectiveScrollBarWidth;

  if Length(FProjects) = 0 then
  begin
    FScrollView.ScrollArea.Width  := AreaW;
    FScrollView.ScrollArea.Height := FScrollView.Height;
    Exit;
  end;

  TotalH := (RowH + RowGap) * Length(FProjects) + RowGap;
  FScrollView.ScrollArea.Width  := AreaW;
  FScrollView.ScrollArea.Height := TotalH;

  CurBottom := TotalH - RowGap;
  for I := 0 to FScrollView.ScrollArea.ControlsCount - 1 do
  begin
    Row := FScrollView.ScrollArea.Controls[I];
    CurBottom := CurBottom - RowH;
    Row.Translation := Vector2(0, CurBottom);
    Row.Width := AreaW;
    CurBottom := CurBottom - RowGap;
  end;
end;

procedure TViewHome.OnThemeChange;
begin
  { Rebuild the view from scratch when the theme changes. }
  if Container <> nil then
    Container.View := Self;
end;

end.
