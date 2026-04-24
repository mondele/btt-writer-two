{$mode objfpc}{$H+}
unit GameViewSettings;

{ Settings screen — full-screen view reached from the ⋮ menu.

  Layout: single scrollable list with blue section headers and
  label+value (or toggle) rows, matching v1 settings-*-en.png.

  Sections: General, About, Legal, Advanced.
  Theme cycling is on the Color Theme row (tap to cycle Light/Dark/System).
}

interface

uses
  Classes,
  CastleUIControls, CastleControls, CastleColors,
  CGEViewBase, BTTHeader, BTTBreadcrumb, BTTStatusBar, BTTClickableRow,
  BTTTheme;

type
  { Populated lazily: the scroll-area holds one content child per row. }
  TViewSettings = class(TCGEViewBase)
  private
    FHeader       : TBTTHeader;
    FCrumb        : TBTTBreadcrumb;
    FStatusBar    : TBTTStatusBar;
    FScrollView   : TCastleScrollView;
    FRows         : TCastleUserInterface;  { container owned by scroll area }

    { Cached handles for rows whose value changes at runtime. }
    FThemeRow     : TBTTClickableRow;
    FGatewayRow   : TBTTClickableRow;
    FGatewayCheck : TCastleLabel;   { ☐ / ☑ as text glyph }
    FBlindRow     : TBTTClickableRow;
    FBlindCheck   : TCastleLabel;

    FNeedsRelayout: Boolean;

    procedure BuildChrome;
    procedure BuildList;
    procedure LayoutList;
    procedure UpdateThemeValue;
    procedure UpdateGatewayCheck;
    procedure UpdateBlindCheck;

    function AddSectionHeader(const ACaption: string): TCastleLabel;
    function AddValueRow(const ALabel, AValue: string;
      OnClick: TNotifyEvent = nil): TBTTClickableRow;
    function AddToggleRow(const ALabel, ADescription: string;
      var CheckLblOut: TCastleLabel;
      OnClick: TNotifyEvent): TBTTClickableRow;
    procedure AddSeparator;

    procedure ClickBack(Sender: TObject);
    procedure ClickTheme(Sender: TObject);
    procedure ClickGateway(Sender: TObject);
    procedure ClickBlind(Sender: TObject);
    procedure ClickLegalLicense(Sender: TObject);
    procedure ClickLegalGuide(Sender: TObject);
    procedure ClickLegalFaith(Sender: TObject);
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
  AppState, AppLog, AppSettings, DataPaths, Globals, CGEStrings,
  GameViewHome;

const
  RowPad      : Single = 20;
  RowH        : Single = 64;   { single-line rows }
  RowH2       : Single = 78;   { two-line rows (label + desc/value) }
  SectionH    : Single = 46;
  SepH        : Single = 1;
  CheckGlyphOn  = #$E2#$98#$91;  { ☑ U+2611 }
  CheckGlyphOff = #$E2#$98#$90;  { ☐ U+2610 }

{ ── TViewSettings ─────────────────────────────────────────────────────────── }

procedure TViewSettings.Start;
begin
  inherited;
  ApplyBackground;
  BuildChrome;
  BuildList;
  FNeedsRelayout := True;
end;

procedure TViewSettings.BuildChrome;
var
  Pal : TBTTPalette;
begin
  Pal := P;

  FHeader := TBTTHeader.Create(FreeAtStop, Pal);
  FHeader.SetTitle(rsAppName);
  InsertFront(FHeader);

  FCrumb := TBTTBreadcrumb.Create(FreeAtStop, Pal);
  FCrumb.OnBack := @ClickBack;
  FCrumb.SetCrumbs([rsNewProjCrumbHome, rsSettingsCrumb]);
  InsertFront(FCrumb);

  FScrollView := TCastleScrollView.Create(FreeAtStop);
  InsertFront(FScrollView);

  FStatusBar := TBTTStatusBar.Create(FreeAtStop, Pal);
  InsertFront(FStatusBar);

  { Owner for all row controls — manually sized in LayoutList.
    (FullSize would pin it to ScrollArea's visible size, breaking scrolling.) }
  FRows := TCastleUserInterface.Create(FreeAtStop);
  FRows.Anchor(hpLeft, hpLeft, 0);
  FRows.Anchor(vpBottom, vpBottom, 0);
  FScrollView.ScrollArea.InsertFront(FRows);
end;

function TViewSettings.AddSectionHeader(const ACaption: string): TCastleLabel;
var
  Pal : TBTTPalette;
begin
  Pal := P;
  Result          := TCastleLabel.Create(FRows);
  Result.Caption  := ACaption;
  Result.Color    := Pal.Primary;
  Result.FontSize := 16;
  Result.Anchor(hpLeft, hpLeft, RowPad);
  { Vertical position set in LayoutList. Tag = 1 means "section header". }
  Result.Tag := 1;
  FRows.InsertFront(Result);
end;

function TViewSettings.AddValueRow(const ALabel, AValue: string;
  OnClick: TNotifyEvent): TBTTClickableRow;
var
  Pal      : TBTTPalette;
  LblLabel : TCastleLabel;
  LblValue : TCastleLabel;
begin
  Pal := P;
  Result        := TBTTClickableRow.Create(FRows);
  Result.Color  := Pal.PanelBg;
  Result.Anchor(hpLeft, hpLeft, 0);
  Result.OnRowClick := OnClick;
  { Tag = 2: two-line row (RowH2). }
  Result.Tag := 2;
  FRows.InsertFront(Result);

  LblLabel          := TCastleLabel.Create(Result);
  LblLabel.Caption  := ALabel;
  LblLabel.Color    := Pal.TextPrimary;
  LblLabel.FontSize := 15;
  LblLabel.Anchor(hpLeft, hpLeft, RowPad);
  LblLabel.Anchor(vpTop,  vpTop,  -14);
  Result.InsertFront(LblLabel);

  LblValue          := TCastleLabel.Create(Result);
  LblValue.Caption  := AValue;
  LblValue.Color    := Pal.TextSecondary;
  LblValue.FontSize := 13;
  LblValue.Anchor(hpLeft, hpLeft, RowPad);
  LblValue.Anchor(vpBottom, vpBottom, 14);
  Result.InsertFront(LblValue);

  { Store the value label on the row's private via a second Tag field
    only if caller needs it — we return the row and let callers dig it out. }
end;

function TViewSettings.AddToggleRow(const ALabel, ADescription: string;
  var CheckLblOut: TCastleLabel;
  OnClick: TNotifyEvent): TBTTClickableRow;
var
  Pal      : TBTTPalette;
  LblLabel : TCastleLabel;
  LblDesc  : TCastleLabel;
  Check    : TCastleLabel;
begin
  Pal := P;
  Result        := TBTTClickableRow.Create(FRows);
  Result.Color  := Pal.PanelBg;
  Result.Anchor(hpLeft, hpLeft, 0);
  Result.OnRowClick := OnClick;
  Result.Tag := 2;  { two-line }
  FRows.InsertFront(Result);

  LblLabel          := TCastleLabel.Create(Result);
  LblLabel.Caption  := ALabel;
  LblLabel.Color    := Pal.TextPrimary;
  LblLabel.FontSize := 15;
  LblLabel.Anchor(hpLeft, hpLeft, RowPad);
  LblLabel.Anchor(vpTop,  vpTop,  -14);
  Result.InsertFront(LblLabel);

  LblDesc          := TCastleLabel.Create(Result);
  LblDesc.Caption  := ADescription;
  LblDesc.Color    := Pal.TextSecondary;
  LblDesc.FontSize := 13;
  LblDesc.Anchor(hpLeft, hpLeft, RowPad);
  LblDesc.Anchor(vpBottom, vpBottom, 14);
  Result.InsertFront(LblDesc);

  Check          := TCastleLabel.Create(Result);
  Check.Caption  := CheckGlyphOff;
  Check.Color    := Pal.Primary;
  Check.FontSize := 18;
  Check.Anchor(hpRight,  hpRight,  -RowPad);
  Check.Anchor(vpMiddle, vpMiddle);
  Result.InsertFront(Check);

  CheckLblOut := Check;
end;

procedure TViewSettings.AddSeparator;
var
  Pal : TBTTPalette;
  Sep : TCastleRectangleControl;
begin
  Pal := P;
  Sep        := TCastleRectangleControl.Create(FRows);
  Sep.Color  := Pal.Border;
  Sep.Height := SepH;
  Sep.Anchor(hpLeft, hpLeft, RowPad);
  Sep.Tag := 3;  { separator }
  FRows.InsertFront(Sep);
end;

procedure TViewSettings.BuildList;
begin
  { General }
  AddSectionHeader(rsSettingsSectionGeneral);
  AddValueRow('Interface Language', 'English', nil);
  AddSeparator;
  FGatewayRow := AddToggleRow('Gateway Language Mode',
    'Display additional translation options for gateway languages',
    FGatewayCheck, @ClickGateway);
  AddSeparator;
  FBlindRow := AddToggleRow('Blind Edit Mode',
    'Display translation mode option that allows for blind drafting',
    FBlindCheck, @ClickBlind);
  AddSeparator;
  FThemeRow := AddValueRow(rsSettingsTheme, '', @ClickTheme);
  UpdateThemeValue;
  UpdateGatewayCheck;
  UpdateBlindCheck;
  AddSeparator;
  AddValueRow('Backup Location', GetBackupLocation, nil);
  AddSeparator;

  { About }
  AddSectionHeader(rsSettingsSectionAbout);
  AddValueRow('App Version', APP_VERSION, nil);
  AddSeparator;
  AddValueRow('Data Path', GetDataPath, nil);
  AddSeparator;

  { Legal }
  AddSectionHeader(rsSettingsSectionLegal);
  AddValueRow(rsTermsLicenseAgreement, '', @ClickLegalLicense);
  AddSeparator;
  AddValueRow(rsTermsTranslationGuide, '', @ClickLegalGuide);
  AddSeparator;
  AddValueRow(rsTermsStatementOfFaith, '', @ClickLegalFaith);
  AddSeparator;

  { Advanced }
  AddSectionHeader(rsSettingsSectionAdvanced);
  AddValueRow('Server Suite (e.g. WACS or DCS)', GetServerSuite, nil);
  AddSeparator;
  AddValueRow('Data Server', GetDataServer, nil);
  AddSeparator;
end;

procedure TViewSettings.UpdateThemeValue;
var
  Row: TCastleUserInterface;
  I: Integer;
  Lbl: TCastleLabel;
  ThemeName: string;
begin
  case GetAppTheme of
    atLight:  ThemeName := rsSettingsThemeLight;
    atDark:   ThemeName := rsSettingsThemeDark;
    atSystem: ThemeName := rsSettingsThemeSystem;
  else
    ThemeName := '';
  end;

  if FThemeRow = nil then Exit;
  { The value label is the 2nd child (index 1) of the row. }
  for I := 0 to FThemeRow.ControlsCount - 1 do
  begin
    Row := FThemeRow.Controls[I];
    if (Row is TCastleLabel) and (TCastleLabel(Row).FontSize = 13) then
    begin
      Lbl := TCastleLabel(Row);
      Lbl.Caption := ThemeName;
      Break;
    end;
  end;
end;

procedure TViewSettings.UpdateGatewayCheck;
begin
  if FGatewayCheck = nil then Exit;
  if GetGatewayLanguageMode then
    FGatewayCheck.Caption := CheckGlyphOn
  else
    FGatewayCheck.Caption := CheckGlyphOff;
end;

procedure TViewSettings.UpdateBlindCheck;
begin
  if FBlindCheck = nil then Exit;
  if GetBlindEditMode then
    FBlindCheck.Caption := CheckGlyphOn
  else
    FBlindCheck.Caption := CheckGlyphOff;
end;

procedure TViewSettings.LayoutList;
var
  AreaW, TotalH, CurY, ItemH: Single;
  I: Integer;
  Item: TCastleUserInterface;
begin
  if (FScrollView = nil) or (FRows = nil) then Exit;
  AreaW := FScrollView.EffectiveWidthForChildren
         - FScrollView.EffectiveScrollBarWidth;
  if AreaW < 1 then Exit;

  FScrollView.ScrollArea.Width  := AreaW;
  FRows.Width := AreaW;

  { Measure total height. }
  TotalH := 0;
  for I := 0 to FRows.ControlsCount - 1 do
  begin
    Item := FRows.Controls[I];
    case Item.Tag of
      1: ItemH := SectionH;
      2: ItemH := RowH2;
      3: ItemH := SepH;
    else
      ItemH := RowH;
    end;
    TotalH := TotalH + ItemH;
  end;

  FScrollView.ScrollArea.Height := Max(FScrollView.Height, TotalH);
  FRows.Height := TotalH;

  { Position from top down (CGE: y=0 at bottom). }
  CurY := TotalH;
  for I := 0 to FRows.ControlsCount - 1 do
  begin
    Item := FRows.Controls[I];
    case Item.Tag of
      1: ItemH := SectionH;
      2: ItemH := RowH2;
      3: ItemH := SepH;
    else
      ItemH := RowH;
    end;
    CurY := CurY - ItemH;

    Item.Width := AreaW;
    if Item is TCastleRectangleControl then
    begin
      TCastleRectangleControl(Item).Height := ItemH;
      Item.Translation := Vector2(0, CurY);
    end
    else if Item is TCastleLabel then
    begin
      { Labels (section headers) need a translation; width is not meaningful. }
      Item.Translation := Vector2(RowPad, CurY + (ItemH - TCastleLabel(Item).EffectiveHeight) / 2);
    end;
  end;
end;

procedure TViewSettings.ClickBack(Sender: TObject);
begin
  Container.View := ViewHome;
end;

procedure TViewSettings.ClickTheme(Sender: TObject);
begin
  case GetAppTheme of
    atLight:  SetAppTheme(atDark);
    atDark:   SetAppTheme(atSystem);
    atSystem: SetAppTheme(atLight);
  end;
  { Rebuild the view so the new palette applies everywhere. }
  Container.View := Self;
end;

procedure TViewSettings.ClickGateway(Sender: TObject);
begin
  SetGatewayLanguageMode(not GetGatewayLanguageMode);
  UpdateGatewayCheck;
end;

procedure TViewSettings.ClickBlind(Sender: TObject);
begin
  SetBlindEditMode(not GetBlindEditMode);
  UpdateBlindCheck;
end;

procedure TViewSettings.ClickLegalLicense(Sender: TObject);
begin
  LogInfo('Settings: License Agreement tapped (stub)');
end;

procedure TViewSettings.ClickLegalGuide(Sender: TObject);
begin
  LogInfo('Settings: Translation Guidelines tapped (stub)');
end;

procedure TViewSettings.ClickLegalFaith(Sender: TObject);
begin
  LogInfo('Settings: Statement of Faith tapped (stub)');
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

  FCrumb.Translation := Vector2(0, H - BTT_HEADER_H - BTT_BREADCRUMB_H);
  FCrumb.Width       := W;
  FCrumb.Height      := BTT_BREADCRUMB_H;

  FStatusBar.Translation := Vector2(0, 0);
  FStatusBar.Width       := W;
  FStatusBar.Height      := BTT_STATUS_H;

  FScrollView.Translation := Vector2(0, BTT_STATUS_H);
  FScrollView.Width       := W;
  FScrollView.Height      := H - BTT_HEADER_H - BTT_BREADCRUMB_H - BTT_STATUS_H;

  FNeedsRelayout := True;
end;

procedure TViewSettings.Update(const SecondsPassed: Single;
  var HandleInput: Boolean);
begin
  inherited;
  if FNeedsRelayout then
  begin
    FNeedsRelayout := False;
    LayoutList;
  end;
end;

procedure TViewSettings.OnThemeChange;
begin
  if Container <> nil then
    Container.View := Self;
end;

end.
