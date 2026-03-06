unit ThemePalette;

{$mode objfpc}{$H+}

interface

uses
  Graphics, AppSettings;

type
  TThemePalette = record
    WindowBg: TColor;
    HeaderBg: TColor;
    StatusBg: TColor;
    RailBg: TColor;
    ContentBg: TColor;
    PanelBg: TColor;
    SecondaryPanelBg: TColor;
    ResourceTabBg: TColor;
    MemoBg: TColor;
    TextPrimary: TColor;
    TextSecondary: TColor;
    TextMuted: TColor;
    TextInverse: TColor;
  end;

function GetThemePalette(ATheme: TAppTheme): TThemePalette;

implementation

function GetThemePalette(ATheme: TAppTheme): TThemePalette;
begin
  if ATheme = atDark then
  begin
    Result.WindowBg := $00222222;
    Result.HeaderBg := $002B2B2B;
    Result.StatusBg := $002B2B2B;
    Result.RailBg := $00303030;
    Result.ContentBg := $00262626;
    Result.PanelBg := $002D2D2D;
    Result.SecondaryPanelBg := $002A2A2A;
    Result.ResourceTabBg := $00333333;
    Result.MemoBg := $00252525;
    Result.TextPrimary := clWhite;
    Result.TextSecondary := $00D0D0D0;
    Result.TextMuted := $00C8C8C8;
    Result.TextInverse := clWhite;
  end
  else
  begin
    Result.WindowBg := clWhite;
    Result.HeaderBg := 5841152;
    Result.StatusBg := 16567595;
    Result.RailBg := 13848578;
    Result.ContentBg := 14474460;
    Result.PanelBg := clWhite;
    Result.SecondaryPanelBg := 15263976;
    Result.ResourceTabBg := clWhite;
    Result.MemoBg := clWhite;
    Result.TextPrimary := 2105376;
    Result.TextSecondary := 7303023;
    Result.TextMuted := 9013641;
    Result.TextInverse := clWhite;
  end;
end;

end.
