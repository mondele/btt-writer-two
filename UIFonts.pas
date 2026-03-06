unit UIFonts;

{$mode objfpc}{$H+}

interface

uses
  Controls;

procedure ApplyFontRecursive(Root: TControl; const FontName: string);

implementation

procedure ApplyFontRecursive(Root: TControl; const FontName: string);
var
  I: Integer;
  WC: TWinControl;
begin
  if Root = nil then
    Exit;
  Root.Font.Name := FontName;
  if Root is TWinControl then
  begin
    WC := TWinControl(Root);
    for I := 0 to WC.ControlCount - 1 do
      ApplyFontRecursive(WC.Controls[I], FontName);
  end;
end;

end.
