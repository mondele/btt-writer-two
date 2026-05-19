unit BookCodes;

{$mode objfpc}{$H+}

{ Shared Bible book code helpers: canonical order, USFM book numbers,
  and uppercase USFM code form. Used by the GUI sort logic and by the
  monolithic-USFM filename builder. }

interface

const
  BOOK_ORDER: array[0..65] of string = (
    'gen','exo','lev','num','deu','jos','jdg','rut','1sa','2sa','1ki','2ki',
    '1ch','2ch','ezr','neh','est','job','psa','pro','ecc','sng','isa','jer',
    'lam','ezk','dan','hos','jol','amo','oba','jon','mic','nam','hab','zep',
    'hag','zec','mal','mat','mrk','luk','jhn','act','rom','1co','2co','gal',
    'eph','php','col','1th','2th','1ti','2ti','tit','phm','heb','jas','1pe',
    '2pe','1jn','2jn','3jn','jud','rev'
  );

{ Canonical index 0..65 in BOOK_ORDER, or 9999 if unknown. Code matching
  is case-insensitive on the trimmed value. }
function CanonicalBookIndex(const BookCode: string): Integer;

{ USFM book number per Paratext convention. OT 01-39, NT 41-67 (40 is
  intentionally skipped — historic gap). Returns 0 if unknown. }
function USFMBookNumber(const BookCode: string): Integer;

{ Uppercase USFM book code (e.g. 'JDG' from 'jdg'). Empty if unknown. }
function USFMBookCodeUpper(const BookCode: string): string;

implementation

uses
  SysUtils;

function CanonicalBookIndex(const BookCode: string): Integer;
var
  I: Integer;
  C: string;
begin
  C := LowerCase(Trim(BookCode));
  for I := Low(BOOK_ORDER) to High(BOOK_ORDER) do
    if BOOK_ORDER[I] = C then
      Exit(I);
  Result := 9999;
end;

function USFMBookNumber(const BookCode: string): Integer;
var
  Idx: Integer;
begin
  Idx := CanonicalBookIndex(BookCode);
  if Idx = 9999 then
    Exit(0);
  if Idx <= 38 then
    Result := Idx + 1
  else
    Result := Idx + 2;
end;

function USFMBookCodeUpper(const BookCode: string): string;
begin
  if CanonicalBookIndex(BookCode) = 9999 then
    Result := ''
  else
    Result := UpperCase(Trim(BookCode));
end;

end.
