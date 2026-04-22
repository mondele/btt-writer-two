{$mode objfpc}{$H+}
unit CanonBooks;

{ Pure canonical Bible book data — no LCL dependency.
  Extracted from ProjectCreator so both LCL and CGE builds can share it. }

interface

uses SysUtils;

type
  TCanonicalBook = record
    Code : string;
    Name : string;
    IsOT : Boolean;
  end;

const
  CANON_BOOKS: array[0..65] of TCanonicalBook = (
    (Code: 'gen'; Name: 'Genesis';          IsOT: True),
    (Code: 'exo'; Name: 'Exodus';           IsOT: True),
    (Code: 'lev'; Name: 'Leviticus';        IsOT: True),
    (Code: 'num'; Name: 'Numbers';          IsOT: True),
    (Code: 'deu'; Name: 'Deuteronomy';      IsOT: True),
    (Code: 'jos'; Name: 'Joshua';           IsOT: True),
    (Code: 'jdg'; Name: 'Judges';           IsOT: True),
    (Code: 'rut'; Name: 'Ruth';             IsOT: True),
    (Code: '1sa'; Name: '1 Samuel';         IsOT: True),
    (Code: '2sa'; Name: '2 Samuel';         IsOT: True),
    (Code: '1ki'; Name: '1 Kings';          IsOT: True),
    (Code: '2ki'; Name: '2 Kings';          IsOT: True),
    (Code: '1ch'; Name: '1 Chronicles';     IsOT: True),
    (Code: '2ch'; Name: '2 Chronicles';     IsOT: True),
    (Code: 'ezr'; Name: 'Ezra';             IsOT: True),
    (Code: 'neh'; Name: 'Nehemiah';         IsOT: True),
    (Code: 'est'; Name: 'Esther';           IsOT: True),
    (Code: 'job'; Name: 'Job';              IsOT: True),
    (Code: 'psa'; Name: 'Psalms';           IsOT: True),
    (Code: 'pro'; Name: 'Proverbs';         IsOT: True),
    (Code: 'ecc'; Name: 'Ecclesiastes';     IsOT: True),
    (Code: 'sng'; Name: 'Song of Solomon';  IsOT: True),
    (Code: 'isa'; Name: 'Isaiah';           IsOT: True),
    (Code: 'jer'; Name: 'Jeremiah';         IsOT: True),
    (Code: 'lam'; Name: 'Lamentations';     IsOT: True),
    (Code: 'ezk'; Name: 'Ezekiel';          IsOT: True),
    (Code: 'dan'; Name: 'Daniel';           IsOT: True),
    (Code: 'hos'; Name: 'Hosea';            IsOT: True),
    (Code: 'jol'; Name: 'Joel';             IsOT: True),
    (Code: 'amo'; Name: 'Amos';             IsOT: True),
    (Code: 'oba'; Name: 'Obadiah';          IsOT: True),
    (Code: 'jon'; Name: 'Jonah';            IsOT: True),
    (Code: 'mic'; Name: 'Micah';            IsOT: True),
    (Code: 'nam'; Name: 'Nahum';            IsOT: True),
    (Code: 'hab'; Name: 'Habakkuk';         IsOT: True),
    (Code: 'zep'; Name: 'Zephaniah';        IsOT: True),
    (Code: 'hag'; Name: 'Haggai';           IsOT: True),
    (Code: 'zec'; Name: 'Zechariah';        IsOT: True),
    (Code: 'mal'; Name: 'Malachi';          IsOT: True),
    (Code: 'mat'; Name: 'Matthew';          IsOT: False),
    (Code: 'mrk'; Name: 'Mark';             IsOT: False),
    (Code: 'luk'; Name: 'Luke';             IsOT: False),
    (Code: 'jhn'; Name: 'John';             IsOT: False),
    (Code: 'act'; Name: 'Acts';             IsOT: False),
    (Code: 'rom'; Name: 'Romans';           IsOT: False),
    (Code: '1co'; Name: '1 Corinthians';    IsOT: False),
    (Code: '2co'; Name: '2 Corinthians';    IsOT: False),
    (Code: 'gal'; Name: 'Galatians';        IsOT: False),
    (Code: 'eph'; Name: 'Ephesians';        IsOT: False),
    (Code: 'php'; Name: 'Philippians';      IsOT: False),
    (Code: 'col'; Name: 'Colossians';       IsOT: False),
    (Code: '1th'; Name: '1 Thessalonians';  IsOT: False),
    (Code: '2th'; Name: '2 Thessalonians';  IsOT: False),
    (Code: '1ti'; Name: '1 Timothy';        IsOT: False),
    (Code: '2ti'; Name: '2 Timothy';        IsOT: False),
    (Code: 'tit'; Name: 'Titus';            IsOT: False),
    (Code: 'phm'; Name: 'Philemon';         IsOT: False),
    (Code: 'heb'; Name: 'Hebrews';          IsOT: False),
    (Code: 'jas'; Name: 'James';            IsOT: False),
    (Code: '1pe'; Name: '1 Peter';          IsOT: False),
    (Code: '2pe'; Name: '2 Peter';          IsOT: False),
    (Code: '1jn'; Name: '1 John';           IsOT: False),
    (Code: '2jn'; Name: '2 John';           IsOT: False),
    (Code: '3jn'; Name: '3 John';           IsOT: False),
    (Code: 'jud'; Name: 'Jude';             IsOT: False),
    (Code: 'rev'; Name: 'Revelation';       IsOT: False)
  );

{ Returns True and sets IsOT if BookCode is a recognised canonical code. }
function CanonicalBookIsOT(const BookCode: string; out IsOT: Boolean): Boolean;

{ Returns True if BookCode is in CANON_BOOKS. }
function IsCanonicalBibleBookCode(const BookCode: string): Boolean;

{ Returns the display name for a book code, or '' if not found. }
function CanonicalBookName(const BookCode: string): string;

implementation

function CanonicalBookIsOT(const BookCode: string; out IsOT: Boolean): Boolean;
var
  I: Integer;
  Code: string;
begin
  Result := False;
  IsOT   := False;
  Code   := LowerCase(Trim(BookCode));
  for I := 0 to High(CANON_BOOKS) do
    if CANON_BOOKS[I].Code = Code then
    begin
      IsOT   := CANON_BOOKS[I].IsOT;
      Result := True;
      Exit;
    end;
end;

function IsCanonicalBibleBookCode(const BookCode: string): Boolean;
var
  Dummy: Boolean;
begin
  Result := CanonicalBookIsOT(BookCode, Dummy);
end;

function CanonicalBookName(const BookCode: string): string;
var
  I: Integer;
  Code: string;
begin
  Result := '';
  Code   := LowerCase(Trim(BookCode));
  for I := 0 to High(CANON_BOOKS) do
    if CANON_BOOKS[I].Code = Code then
      Exit(CANON_BOOKS[I].Name);
end;

end.
