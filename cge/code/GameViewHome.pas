{$mode objfpc}{$H+}
unit GameViewHome;

{ Home screen.
  Chrome: BTTHeader (top) + BTTSideRail (left) + scrollable project list.
  Tapping a row stores the project in GAppState and navigates to the editor. }

interface

uses
  Classes,
  CastleUIControls, CastleControls, CastleColors,
  CGEViewBase, BTTHeader, BTTSideRail,
  ProjectScanner;

type
  TViewHome = class(TCGEViewBase)
  private
    FHeader     : TBTTHeader;
    FRail       : TBTTSideRail;
    FScrollView : TCastleScrollView;
    FUserLbl    : TCastleLabel;
    FProjects   : TProjectSummaryList;

    procedure BuildChrome;
    procedure BuildProjectList;
    procedure UpdateScrollArea;
    procedure ClickProject(Sender: TObject);
    procedure ClickMenu(Sender: TObject);
  public
    procedure Start; override;
    procedure Resize; override;
    procedure OnThemeChange; override;
  end;

var
  ViewHome: TViewHome;

implementation

uses
  SysUtils, CastleVectors,
  AppState, BTTTheme,
  GameViewEditor;

const
  RowH   = 72;
  RowGap = 2;
  RowPad = 16;

{ TViewHome }

procedure TViewHome.Start;
begin
  inherited;
  ApplyBackground;
  FProjects := ScanProjects;
  BuildChrome;
  BuildProjectList;
end;

procedure TViewHome.BuildChrome;
var
  Pal: TBTTPalette;
begin
  Pal := P;

  FHeader := TBTTHeader.Create(FreeAtStop, Pal);
  FHeader.SetTitle('BTT-Writer');
  InsertFront(FHeader);

  FUserLbl := TCastleLabel.Create(FreeAtStop);
  FUserLbl.Caption  := GAppState.UserName;
  FUserLbl.Color    := Pal.TextInverse;
  FUserLbl.FontSize := 13;
  FHeader.AddRight(FUserLbl);

  FRail := TBTTSideRail.Create(FreeAtStop, Pal);
  FRail.OnMenuClick := @ClickMenu;
  InsertFront(FRail);

  FScrollView := TCastleScrollView.Create(FreeAtStop);
  InsertFront(FScrollView);
end;

procedure TViewHome.BuildProjectList;
var
  Pal: TBTTPalette;
  I: Integer;
  Row: TCastleRectangleControl;
  NameLbl, DetailLbl, EmptyLbl: TCastleLabel;
  Btn: TCastleButton;
begin
  Pal := P;

  if Length(FProjects) = 0 then
  begin
    EmptyLbl := TCastleLabel.Create(FreeAtStop);
    EmptyLbl.Caption :=
      'No translation projects found.' + LineEnding +
      'Projects are stored in:' + LineEnding +
      '~/.config/BTT-Writer/targetTranslations/';
    EmptyLbl.Color     := Pal.TextSecondary;
    EmptyLbl.FontSize  := 15;
    EmptyLbl.Alignment := hpMiddle;
    EmptyLbl.Anchor(hpMiddle, hpMiddle);
    EmptyLbl.Anchor(vpMiddle, vpMiddle);
    FScrollView.ScrollArea.InsertFront(EmptyLbl);
    Exit;
  end;

  for I := 0 to High(FProjects) do
  begin
    Row := TCastleRectangleControl.Create(FreeAtStop);
    Row.Color  := Pal.PanelBg;
    Row.Height := RowH;
    Row.Tag    := I;
    FScrollView.ScrollArea.InsertFront(Row);

    NameLbl := TCastleLabel.Create(FreeAtStop);
    NameLbl.Caption := FProjects[I].BookName + '  (' + FProjects[I].TargetLangCode + ')';
    NameLbl.Color   := Pal.TextPrimary;
    NameLbl.FontSize := 16;
    NameLbl.Anchor(hpLeft, hpLeft, RowPad);
    NameLbl.Anchor(vpTop, vpTop, -14);
    Row.InsertFront(NameLbl);

    DetailLbl := TCastleLabel.Create(FreeAtStop);
    DetailLbl.Caption :=
      FProjects[I].ResourceType + '  •  ' +
      IntToStr(FProjects[I].FinishedChunks) + ' / ' +
      IntToStr(FProjects[I].TotalChunks) + ' chunks';
    DetailLbl.Color   := Pal.TextSecondary;
    DetailLbl.FontSize := 13;
    DetailLbl.Anchor(hpLeft, hpLeft, RowPad);
    DetailLbl.Anchor(vpBottom, vpBottom, 14);
    Row.InsertFront(DetailLbl);

    Btn := TCastleButton.Create(FreeAtStop);
    Btn.Caption  := 'Open';
    Btn.FontSize := 13;
    Btn.Tag      := I;
    Btn.OnClick  := @ClickProject;
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

  GAppState.Screen               := asEditor;
  GAppState.Editor.ProjectDir    := FProjects[I].FullPath;
  GAppState.Editor.ProjectTitle  :=
    FProjects[I].BookName + ' — ' + FProjects[I].TargetLangCode;
  GAppState.Editor.BookCode      := FProjects[I].BookCode;
  GAppState.Editor.TargetLangCode := FProjects[I].TargetLangCode;
  GAppState.Editor.ChapterIndex  := 0;
  GAppState.Editor.ChunkIndex    := -1;

  Container.View := ViewEditor;
end;

procedure TViewHome.ClickMenu(Sender: TObject);
begin
  { Phase 2: show main menu popup }
end;

procedure TViewHome.Resize;
var
  W, H: Single;
begin
  inherited;
  if FHeader = nil then Exit;
  W := EffectiveWidth;
  H := EffectiveHeight;

  { Header: full width across the top }
  FHeader.Translation := Vector2(0, H - BTT_HEADER_H);
  FHeader.Width       := W;
  FHeader.Height      := BTT_HEADER_H;

  { Rail: left column below header }
  FRail.Translation := Vector2(0, 0);
  FRail.Width       := BTT_RAIL_W;
  FRail.Height      := H - BTT_HEADER_H;

  { Scroll view: remaining space }
  FScrollView.Translation := Vector2(BTT_RAIL_W, 0);
  FScrollView.Width       := W - BTT_RAIL_W;
  FScrollView.Height      := H - BTT_HEADER_H;

  UpdateScrollArea;
end;

procedure TViewHome.UpdateScrollArea;
var
  I: Integer;
  AreaW, TotalH, CurBottom: Single;
  Row: TCastleUserInterface;
begin
  if FScrollView = nil then Exit;

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
    Row.Width       := AreaW;
    CurBottom       := CurBottom - RowGap;
  end;
end;

procedure TViewHome.OnThemeChange;
begin
  if Container <> nil then
    Container.View := Self;
end;

end.
