{$mode objfpc}{$H+}
unit GameViewSettings;

{ Settings screen — full-screen view reached from the ⋮ menu.

  Sections:
    Theme     — Light / Dark / System buttons; applies immediately.
    About     — app version, data directory path.

  Navigates back to ViewHome via the header Back button.
  Theme change rebuilds the settings view itself; other views pick up
  the new palette the next time they are opened (their Start reloads P).
}

interface

uses
  Classes,
  CastleUIControls, CastleControls, CastleColors,
  CGEViewBase, BTTHeader;

type
  TViewSettings = class(TCGEViewBase)
  private
    FHeader       : TBTTHeader;
    FScrollView   : TCastleScrollView;

    { theme section }
    FThemeHeading : TCastleLabel;
    FLightBtn     : TCastleButton;
    FDarkBtn      : TCastleButton;
    FSystemBtn    : TCastleButton;
    FThemeStatus  : TCastleLabel;

    { about section }
    FAboutHeading : TCastleLabel;
    FVersionLbl   : TCastleLabel;
    FDataPathLbl  : TCastleLabel;

    FNeedsRelayout: Boolean;

    procedure BuildChrome;
    procedure UpdateThemeStatus;
    procedure LayoutScrollContent;

    procedure ClickBack(Sender: TObject);
    procedure ClickLight(Sender: TObject);
    procedure ClickDark(Sender: TObject);
    procedure ClickSystem(Sender: TObject);
  public
    procedure Start;  override;
    procedure Resize; override;
    procedure Update(const SecondsPassed: Single;
                     var HandleInput: Boolean); override;
    procedure OnThemeChange; override;
  end;

var
  ViewSettings: TViewSettings;

implementation

uses
  SysUtils, CastleVectors, Math,
  AppState, BTTTheme, AppLog, AppSettings, DataPaths, Globals,
  GameViewHome;

const
  Pad       = 24;
  SectionGap = 32;
  BtnW      = 120;
  BtnH      = 36;

{ ── TViewSettings ─────────────────────────────────────────────────────────── }

procedure TViewSettings.Start;
begin
  inherited;
  ApplyBackground;
  BuildChrome;
  UpdateThemeStatus;
  FNeedsRelayout := True;
end;

procedure TViewSettings.BuildChrome;
var
  Pal     : TBTTPalette;
  BackBtn : TCastleButton;
begin
  Pal := P;

  FHeader := TBTTHeader.Create(FreeAtStop, Pal);
  FHeader.SetTitle('Settings');
  InsertFront(FHeader);

  BackBtn         := TCastleButton.Create(FreeAtStop);
  BackBtn.Caption := '< Back';
  BackBtn.FontSize := 14;
  BackBtn.OnClick := @ClickBack;
  FHeader.AddLeft(BackBtn);

  FScrollView := TCastleScrollView.Create(FreeAtStop);
  InsertFront(FScrollView);

  { ── Theme section ── }
  FThemeHeading          := TCastleLabel.Create(FreeAtStop);
  FThemeHeading.Caption  := 'Theme';
  FThemeHeading.Color    := Pal.TextPrimary;
  FThemeHeading.FontSize := 17;
  FScrollView.ScrollArea.InsertFront(FThemeHeading);

  FLightBtn         := TCastleButton.Create(FreeAtStop);
  FLightBtn.Caption := 'Light';
  FLightBtn.FontSize := 14;
  FLightBtn.Width   := BtnW;
  FLightBtn.Height  := BtnH;
  FLightBtn.OnClick := @ClickLight;
  FScrollView.ScrollArea.InsertFront(FLightBtn);

  FDarkBtn         := TCastleButton.Create(FreeAtStop);
  FDarkBtn.Caption := 'Dark';
  FDarkBtn.FontSize := 14;
  FDarkBtn.Width   := BtnW;
  FDarkBtn.Height  := BtnH;
  FDarkBtn.OnClick := @ClickDark;
  FScrollView.ScrollArea.InsertFront(FDarkBtn);

  FSystemBtn         := TCastleButton.Create(FreeAtStop);
  FSystemBtn.Caption := 'System';
  FSystemBtn.FontSize := 14;
  FSystemBtn.Width   := BtnW;
  FSystemBtn.Height  := BtnH;
  FSystemBtn.OnClick := @ClickSystem;
  FScrollView.ScrollArea.InsertFront(FSystemBtn);

  FThemeStatus          := TCastleLabel.Create(FreeAtStop);
  FThemeStatus.Caption  := '';
  FThemeStatus.Color    := Pal.TextSecondary;
  FThemeStatus.FontSize := 13;
  FScrollView.ScrollArea.InsertFront(FThemeStatus);

  { ── About section ── }
  FAboutHeading          := TCastleLabel.Create(FreeAtStop);
  FAboutHeading.Caption  := 'About';
  FAboutHeading.Color    := Pal.TextPrimary;
  FAboutHeading.FontSize := 17;
  FScrollView.ScrollArea.InsertFront(FAboutHeading);

  FVersionLbl          := TCastleLabel.Create(FreeAtStop);
  FVersionLbl.Caption  := 'Version: ' + APP_VERSION;
  FVersionLbl.Color    := Pal.TextSecondary;
  FVersionLbl.FontSize := 14;
  FScrollView.ScrollArea.InsertFront(FVersionLbl);

  FDataPathLbl          := TCastleLabel.Create(FreeAtStop);
  FDataPathLbl.Caption  := 'Data: ' + GetDataPath;
  FDataPathLbl.Color    := Pal.TextSecondary;
  FDataPathLbl.FontSize := 13;
  FScrollView.ScrollArea.InsertFront(FDataPathLbl);
end;

procedure TViewSettings.UpdateThemeStatus;
var
  ThemeName: string;
begin
  if FThemeStatus = nil then Exit;
  case GetAppTheme of
    atLight:  ThemeName := 'Light';
    atDark:   ThemeName := 'Dark';
    atSystem: ThemeName := 'System';
  end;
  FThemeStatus.Caption := 'Current: ' + ThemeName;
end;

procedure TViewSettings.LayoutScrollContent;
var
  W, AreaW : Single;
  CurY     : Single;     { CGE y-from-bottom; we'll compute total then position }
  BtnRowY  : Single;
  TotalH   : Single;
begin
  if FScrollView = nil then Exit;
  W    := FScrollView.EffectiveWidthForChildren;
  AreaW := W;
  if AreaW < 1 then Exit;

  { Calculate total content height (top→bottom order in CGE = highest Y first) }
  { We lay out from bottom (y=0) upward, then flip. }
  TotalH := Pad;                { bottom margin }
  TotalH := TotalH + FDataPathLbl.EffectiveHeight + Pad * 0.5;
  TotalH := TotalH + FVersionLbl.EffectiveHeight  + Pad * 0.5;
  TotalH := TotalH + FAboutHeading.EffectiveHeight + SectionGap;
  TotalH := TotalH + FThemeStatus.EffectiveHeight  + Pad * 0.5;
  TotalH := TotalH + BtnH + Pad;       { button row }
  TotalH := TotalH + FThemeHeading.EffectiveHeight + Pad;
  TotalH := TotalH + Pad;              { top margin }

  FScrollView.ScrollArea.Width  := AreaW;
  FScrollView.ScrollArea.Height := Max(FScrollView.Height, TotalH);

  { Position items from top down (CGE: top = TotalH - Pad) }
  CurY := TotalH - Pad;

  CurY := CurY - FThemeHeading.EffectiveHeight;
  FThemeHeading.Translation := Vector2(Pad, CurY);
  CurY := CurY - Pad;

  { Three theme buttons in a row }
  BtnRowY := CurY - BtnH;
  FLightBtn.Translation  := Vector2(Pad, BtnRowY);
  FDarkBtn.Translation   := Vector2(Pad + BtnW + 8, BtnRowY);
  FSystemBtn.Translation := Vector2(Pad + (BtnW + 8) * 2, BtnRowY);
  CurY := BtnRowY - Pad * 0.5;

  CurY := CurY - FThemeStatus.EffectiveHeight;
  FThemeStatus.Translation := Vector2(Pad, CurY);
  CurY := CurY - SectionGap;

  CurY := CurY - FAboutHeading.EffectiveHeight;
  FAboutHeading.Translation := Vector2(Pad, CurY);
  CurY := CurY - Pad * 0.5;

  CurY := CurY - FVersionLbl.EffectiveHeight;
  FVersionLbl.Translation := Vector2(Pad, CurY);
  CurY := CurY - Pad * 0.5;

  FDataPathLbl.MaxWidth := AreaW - Pad * 2;
  CurY := CurY - FDataPathLbl.EffectiveHeight;
  FDataPathLbl.Translation := Vector2(Pad, CurY);
end;

procedure TViewSettings.ClickBack(Sender: TObject);
begin
  Container.View := ViewHome;
end;

procedure TViewSettings.ClickLight(Sender: TObject);
begin
  SetAppTheme(atLight);
  UpdateThemeStatus;
  Container.View := Self;   { rebuild chrome with new palette }
end;

procedure TViewSettings.ClickDark(Sender: TObject);
begin
  SetAppTheme(atDark);
  UpdateThemeStatus;
  Container.View := Self;
end;

procedure TViewSettings.ClickSystem(Sender: TObject);
begin
  SetAppTheme(atSystem);
  UpdateThemeStatus;
  Container.View := Self;
end;

procedure TViewSettings.Resize;
var
  W, H: Single;
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

  FNeedsRelayout := True;
end;

procedure TViewSettings.Update(const SecondsPassed: Single;
  var HandleInput: Boolean);
begin
  inherited;
  if FNeedsRelayout then
  begin
    FNeedsRelayout := False;
    LayoutScrollContent;
  end;
end;

procedure TViewSettings.OnThemeChange;
begin
  if Container <> nil then
    Container.View := Self;
end;

end.
