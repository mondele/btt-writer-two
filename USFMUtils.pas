unit USFMUtils;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes;

{ Find the position of \v N in text, with proper boundary checking
  so that \v 1 does not match \v 10. Returns 0 if not found. }
function FindVerseMarkerPos(const Text: string; VerseNum: Integer): Integer;

{ Extract text from fromVerse to toVerse (inclusive).
  If toVerse = 0, extracts to the next verse marker or end of text. }
function ExtractVerseRange(const Text: string; FromVerse, ToVerse: Integer): string;

{ Return a list of verse numbers found in the text as strings. }
function ParseVerseNumbers(const Text: string): TStringList;

{ Convert USX markup to plain text with USFM verse markers.
  Replaces <verse number="N" style="v" /> with \v N
  and strips <para> tags. }
function UsxToPlainText(const UsxText: string): string;

implementation

function FindVerseMarkerPos(const Text: string; VerseNum: Integer): Integer;
var
  Marker: string;
  P, TextLen: Integer;
  CharAfter: Char;
begin
  Result := 0;
  Marker := '\v ' + IntToStr(VerseNum);
  TextLen := Length(Text);
  P := 1;

  while P <= TextLen do
  begin
    P := Pos(Marker, Text, P);
    if P = 0 then
      Exit(0);

    { Check that the character after the verse number is a word boundary:
      space, newline, end of string, or another backslash }
    if (P + Length(Marker)) > TextLen then
      Exit(P)  { marker is at end of text }
    else
    begin
      CharAfter := Text[P + Length(Marker)];
      if CharAfter in [' ', #10, #13, '\'] then
        Exit(P);
    end;

    { Not a proper boundary match, keep searching }
    P := P + Length(Marker);
  end;
end;

function ExtractVerseRange(const Text: string; FromVerse, ToVerse: Integer): string;
var
  StartPos, EndPos: Integer;
begin
  Result := '';
  StartPos := FindVerseMarkerPos(Text, FromVerse);
  if StartPos = 0 then
    Exit;

  if ToVerse > 0 then
  begin
    EndPos := FindVerseMarkerPos(Text, ToVerse + 1);
    if EndPos = 0 then
      Result := Copy(Text, StartPos, Length(Text) - StartPos + 1)
    else
      Result := Copy(Text, StartPos, EndPos - StartPos);
  end
  else
  begin
    { Extract to next verse marker or end }
    EndPos := FindVerseMarkerPos(Text, FromVerse + 1);
    if EndPos = 0 then
      Result := Copy(Text, StartPos, Length(Text) - StartPos + 1)
    else
      Result := Copy(Text, StartPos, EndPos - StartPos);
  end;
end;

function ParseVerseNumbers(const Text: string): TStringList;
var
  P, TextLen, NumStart: Integer;
  NumStr: string;
begin
  Result := TStringList.Create;
  Result.Sorted := False;
  TextLen := Length(Text);
  P := 1;

  while P <= TextLen - 2 do  { minimum: \v N }
  begin
    { Look for \v followed by space }
    if (Text[P] = '\') and (P + 2 <= TextLen) and (Text[P + 1] = 'v') and (Text[P + 2] = ' ') then
    begin
      P := P + 3;  { skip past '\v ' }
      NumStart := P;
      while (P <= TextLen) and (Text[P] in ['0'..'9', '-']) do
        Inc(P);
      NumStr := Copy(Text, NumStart, P - NumStart);
      if NumStr <> '' then
        Result.Add(NumStr);
    end
    else
      Inc(P);
  end;
end;

function UsxToPlainText(const UsxText: string): string;
var
  S: string;
  P, TagStart, TagEnd: Integer;
  VerseNum: string;
begin
  S := UsxText;

  { Replace <verse number="N" style="v" /> with \v N }
  repeat
    P := Pos('<verse', S);
    if P = 0 then
      Break;

    TagEnd := Pos('/>', S, P);
    if TagEnd = 0 then
      TagEnd := Pos('>', S, P);
    if TagEnd = 0 then
      Break;

    { Extract verse number from number="N" }
    TagStart := Pos('number="', S, P);
    if (TagStart > 0) and (TagStart < TagEnd) then
    begin
      TagStart := TagStart + Length('number="');
      VerseNum := Copy(S, TagStart, Pos('"', S, TagStart) - TagStart);
    end
    else
      VerseNum := '?';

    { Find actual end of tag }
    if S[TagEnd] = '/' then
      TagEnd := TagEnd + 2  { skip /> }
    else
      TagEnd := TagEnd + 1; { skip > }

    { Replace tag with \v N }
    S := Copy(S, 1, P - 1) + '\v ' + VerseNum + ' ' + Copy(S, TagEnd, Length(S));
  until False;

  { Replace <note ...>...</note> with \f + \f* (footnote indicator) }
  repeat
    P := Pos('<note', S);
    if P = 0 then
      Break;
    TagEnd := Pos('</note>', S, P);
    if TagEnd > 0 then
      TagEnd := TagEnd + Length('</note>')
    else
    begin
      { Self-closing or malformed — just strip the opening tag }
      TagEnd := Pos('>', S, P);
      if TagEnd = 0 then
        Break;
      TagEnd := TagEnd + 1;
    end;
    S := Copy(S, 1, P - 1) + '\f + \f*' + Copy(S, TagEnd, Length(S));
  until False;

  { Strip remaining <char ...> and </char> tags }
  repeat
    P := Pos('<char', S);
    if P = 0 then
      Break;
    TagEnd := Pos('>', S, P);
    if TagEnd = 0 then
      Break;
    S := Copy(S, 1, P - 1) + Copy(S, TagEnd + 1, Length(S));
  until False;

  repeat
    P := Pos('</char>', S);
    if P = 0 then
      Break;
    S := Copy(S, 1, P - 1) + Copy(S, P + Length('</char>'), Length(S));
  until False;

  { Strip <para ...> and </para> tags }
  repeat
    P := Pos('<para', S);
    if P = 0 then
      Break;
    TagEnd := Pos('>', S, P);
    if TagEnd = 0 then
      Break;
    { Check for self-closing <para .../> }
    if (TagEnd > 1) and (S[TagEnd - 1] = '/') then
      S := Copy(S, 1, P - 1) + Copy(S, TagEnd + 1, Length(S))
    else
      S := Copy(S, 1, P - 1) + Copy(S, TagEnd + 1, Length(S));
  until False;

  repeat
    P := Pos('</para>', S);
    if P = 0 then
      Break;
    S := Copy(S, 1, P - 1) + Copy(S, P + Length('</para>'), Length(S));
  until False;

  Result := Trim(S);
end;

end.
