{$mode objfpc}{$H+}
unit BTTTheme;

{ CGE-native colour palette, mirroring the LCL ThemePalette.pas values.
  Uses TCastleColor (RGBA float) instead of TColor (LCL COLORREF).
  Source hex values are the CSS palette from the existing design. }

interface

uses
  CastleColors,
  AppSettings;   { TAppTheme, GetEffectiveTheme }

type
  TBTTPalette = record
    Primary         : TCastleColor;
    PrimaryLight    : TCastleColor;
    PrimaryDark     : TCastleColor;
    Accent          : TCastleColor;
    WindowBg        : TCastleColor;
    HeaderBg        : TCastleColor;
    RailBg          : TCastleColor;
    ContentBg       : TCastleColor;
    PanelBg         : TCastleColor;
    Border          : TCastleColor;
    TextPrimary     : TCastleColor;
    TextSecondary   : TCastleColor;
    TextMuted       : TCastleColor;
    TextInverse     : TCastleColor;
    HeaderText      : TCastleColor;
    RailText        : TCastleColor;
    FinishedBg      : TCastleColor;  { tinted card background for finished chunks }
  end;

function GetBTTPalette(ATheme: TAppTheme): TBTTPalette;
function GetCurrentPalette: TBTTPalette;

implementation

function GetBTTPalette(ATheme: TAppTheme): TBTTPalette;
begin
  if ATheme = atDark then
  begin
    { Dark palette — primary #6A91D3, bg #1C1C1C }
    Result.Primary       := HexToColor('6A91D3');
    Result.PrimaryLight  := HexToColor('E2F0FF');
    Result.PrimaryDark   := HexToColor('445E89');
    Result.Accent        := HexToColor('52A588');
    Result.WindowBg      := HexToColor('1C1C1C');
    Result.HeaderBg      := HexToColor('445E89');
    Result.RailBg        := HexToColor('6A91D3');
    Result.ContentBg     := HexToColor('1C1C1C');
    Result.PanelBg       := HexToColor('272727');
    Result.Border        := HexToColor('333333');
    Result.TextPrimary   := HexToColor('D2D2D2');
    Result.TextSecondary := HexToColor('A4A4A4');
    Result.TextMuted     := HexToColor('777777');
    Result.TextInverse   := HexToColor('1C1C1C');
    Result.HeaderText    := HexToColor('D2D2D2');
    Result.RailText      := HexToColor('1C1C1C');
    Result.FinishedBg    := HexToColor('1E3D2F');  { dark green tint }
  end
  else
  begin
    { Light palette — primary #0250D3, bg #EFEFEF }
    Result.Primary       := HexToColor('0250D3');
    Result.PrimaryLight  := HexToColor('E2F0FF');
    Result.PrimaryDark   := HexToColor('003389');
    Result.Accent        := HexToColor('00A56C');
    Result.WindowBg      := HexToColor('EFEFEF');
    Result.HeaderBg      := HexToColor('003389');
    Result.RailBg        := HexToColor('0250D3');
    Result.ContentBg     := HexToColor('EFEFEF');
    Result.PanelBg       := White;
    Result.Border        := HexToColor('DDDDDD');
    Result.TextPrimary   := HexToColor('1C1C1C');
    Result.TextSecondary := HexToColor('888888');
    Result.TextMuted     := HexToColor('BFBFBF');
    Result.TextInverse   := White;
    Result.HeaderText    := White;
    Result.RailText      := White;
    Result.FinishedBg    := HexToColor('E6F9F0');  { light green tint }
  end;
end;

function GetCurrentPalette: TBTTPalette;
begin
  Result := GetBTTPalette(GetEffectiveTheme);
end;

end.
