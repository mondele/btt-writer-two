unit ThemePalette;

{$mode objfpc}{$H+}

interface

uses
  Graphics, AppSettings;

type
  TThemePalette = record
    Primary: TColor;
    PrimaryLight: TColor;
    PrimaryDark: TColor;
    Accent: TColor;
    WindowBg: TColor;
    HeaderBg: TColor;
    StatusBg: TColor;
    RailBg: TColor;
    ContentBg: TColor;
    PanelBg: TColor;
    SecondaryPanelBg: TColor;
    ResourceTabBg: TColor;
    MemoBg: TColor;
    Border: TColor;
    TextPrimary: TColor;
    TextSecondary: TColor;
    TextMuted: TColor;
    TextInverse: TColor;
    HeaderText: TColor;
    RailText: TColor;
  end;

function GetThemePalette(ATheme: TAppTheme): TThemePalette;

implementation

function GetThemePalette(ATheme: TAppTheme): TThemePalette;
begin
  if ATheme = atDark then
  begin
    { CSS dark palette:
      primary #6A91D3, primary-light #E2F0FF, primary-dark #445E89,
      accent #52A588, background #1C1C1C, card/popup #272727,
      primary text #D2D2D2, secondary #A4A4A4, icon #777777, border #333333,
      reverse text #1C1C1C. }
    Result.Primary := $00D3916A;
    Result.PrimaryLight := $00FFF0E2;
    Result.PrimaryDark := $00895E44;
    Result.Accent := $0088A552;
    Result.WindowBg := $001C1C1C;
    Result.HeaderBg := Result.PrimaryDark;
    Result.StatusBg := Result.PrimaryDark;
    Result.RailBg := Result.Primary;
    Result.ContentBg := $001C1C1C;
    Result.PanelBg := $00272727;
    Result.SecondaryPanelBg := $00272727;
    Result.ResourceTabBg := $00272727;
    Result.MemoBg := $00272727;
    Result.Border := $00333333;
    Result.TextPrimary := $00D2D2D2;
    Result.TextSecondary := $00A4A4A4;
    Result.TextMuted := $00777777;
    Result.TextInverse := $001C1C1C;
    Result.HeaderText := Result.TextPrimary;
    Result.RailText := Result.TextInverse;
  end
  else
  begin
    { CSS light palette:
      primary #0250D3, primary-light #E2F0FF, primary-dark #003389,
      accent #00A56C, background #EFEFEF, card/popup #FFFFFF,
      primary text #1C1C1C, secondary #888888, icon #BFBFBF, border #DDDDDD,
      reverse text #FFFFFF. }
    Result.Primary := $00D35002;
    Result.PrimaryLight := $00FFF0E2;
    Result.PrimaryDark := $00893300;
    Result.Accent := $006CA500;
    Result.WindowBg := $00EFEFEF;
    Result.HeaderBg := Result.PrimaryDark;
    Result.StatusBg := Result.PrimaryDark;
    Result.RailBg := Result.Primary;
    Result.ContentBg := $00EFEFEF;
    Result.PanelBg := clWhite;
    Result.SecondaryPanelBg := clWhite;
    Result.ResourceTabBg := clWhite;
    Result.MemoBg := clWhite;
    Result.Border := $00DDDDDD;
    Result.TextPrimary := $001C1C1C;
    Result.TextSecondary := $00888888;
    Result.TextMuted := $00BFBFBF;
    Result.TextInverse := clWhite;
    Result.HeaderText := Result.TextInverse;
    Result.RailText := Result.TextInverse;
  end;
end;

end.
