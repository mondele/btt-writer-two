{$mode objfpc}{$H+}
unit BTTClickableRow;

{ A TCastleRectangleControl that fires OnRowClick on left-mouse press.
  Used for list rows where the whole row (not just a button inside it)
  should be a click target — e.g. Login option rows, Settings list rows,
  Home menu items. }

interface

uses
  Classes,
  CastleUIControls, CastleControls, CastleKeysMouse;

type
  TBTTClickableRow = class(TCastleRectangleControl)
  private
    FOnRowClick: TNotifyEvent;
  public
    function Press(const Event: TInputPressRelease): Boolean; override;
    property OnRowClick: TNotifyEvent read FOnRowClick write FOnRowClick;
  end;

implementation

function TBTTClickableRow.Press(const Event: TInputPressRelease): Boolean;
begin
  Result := inherited Press(Event);
  if (Event.EventType = itMouseButton) and (Event.MouseButton = buttonLeft) then
  begin
    if Assigned(FOnRowClick) then
      FOnRowClick(Self);
    Result := True;
  end;
end;

end.
