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

type
  TUSFMVerse = record
    Chapter: Integer;
    Verse: Integer;
    Content: string;   { raw text including \v marker }
  end;
  TUSFMVerseArray = array of TUSFMVerse;

  TUSFMParseResult = record
    BookID: string;      { from \id line }
    BookTitle: string;   { from \h or \mt }
    Verses: TUSFMVerseArray;
  end;

function ParseUSFMFile(const FilePath: string; out ParseResult: TUSFMParseResult;
  out ErrorMsg: string): Boolean;

implementation

function FindVerseMarkerPos(const Text: string; VerseNum: Integer): Integer;
var
  P, TextLen, NumStart, NumEnd: Integer;
  VerseToken, VerseNumStr: string;
  DashPos: Integer;
begin
  Result := 0;
  VerseNumStr := IntToStr(VerseNum);
  TextLen := Length(Text);
  P := 1;

  while P <= TextLen do
  begin
    P := Pos('\v ', Text, P);
    if P = 0 then
      Exit(0);

    NumStart := P + 3; { skip "\v " }
    NumEnd := NumStart;
    while (NumEnd <= TextLen) and (Text[NumEnd] in ['0'..'9', '-']) do
      Inc(NumEnd);

    VerseToken := Copy(Text, NumStart, NumEnd - NumStart);
    if VerseToken <> '' then
    begin
      { Support "1" and also range tokens like "1-3". }
      DashPos := Pos('-', VerseToken);
      if DashPos > 0 then
        VerseToken := Copy(VerseToken, 1, DashPos - 1);

      if VerseToken = VerseNumStr then
        Exit(P);
    end;

    P := NumEnd;
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

function ParseUSFMFile(const FilePath: string; out ParseResult: TUSFMParseResult;
  out ErrorMsg: string): Boolean;
var
  SL: TStringList;
  I, CurChapter, CurVerse: Integer;
  Line, Trimmed, Token, Rest: string;
  SpacePos: Integer;
  VerseCount: Integer;
begin
  Result := False;
  ParseResult := Default(TUSFMParseResult);
  ErrorMsg := '';

  if not FileExists(FilePath) then
  begin
    ErrorMsg := 'File not found: ' + FilePath;
    Exit;
  end;

  SL := TStringList.Create;
  try
    SL.LoadFromFile(FilePath);
    CurChapter := 0;
    CurVerse := 0;
    VerseCount := 0;
    SetLength(ParseResult.Verses, 0);

    for I := 0 to SL.Count - 1 do
    begin
      Line := SL[I];
      Trimmed := Trim(Line);
      if Trimmed = '' then
        Continue;

      { Check for markers }
      if (Length(Trimmed) > 1) and (Trimmed[1] = '\') then
      begin
        { Extract marker token }
        SpacePos := Pos(' ', Trimmed);
        if SpacePos > 0 then
        begin
          Token := Copy(Trimmed, 1, SpacePos - 1);
          Rest := Trim(Copy(Trimmed, SpacePos + 1, Length(Trimmed)));
        end
        else
        begin
          Token := Trimmed;
          Rest := '';
        end;

        if Token = '\id' then
        begin
          { \id BOOK description }
          SpacePos := Pos(' ', Rest);
          if SpacePos > 0 then
            ParseResult.BookID := Copy(Rest, 1, SpacePos - 1)
          else
            ParseResult.BookID := Rest;
          Continue;
        end
        else if Token = '\h' then
        begin
          if ParseResult.BookTitle = '' then
            ParseResult.BookTitle := Rest;
          Continue;
        end
        else if Token = '\mt' then
        begin
          if ParseResult.BookTitle = '' then
            ParseResult.BookTitle := Rest;
          Continue;
        end
        else if Token = '\c' then
        begin
          CurChapter := StrToIntDef(Rest, CurChapter + 1);
          CurVerse := 0;
          Continue;
        end
        else if Token = '\v' then
        begin
          { \v NUM text... }
          SpacePos := Pos(' ', Rest);
          if SpacePos > 0 then
          begin
            CurVerse := StrToIntDef(Copy(Rest, 1, SpacePos - 1), CurVerse + 1);
            Rest := Trimmed; { keep the full \v line }
          end
          else
          begin
            CurVerse := StrToIntDef(Rest, CurVerse + 1);
            Rest := Trimmed;
          end;

          Inc(VerseCount);
          SetLength(ParseResult.Verses, VerseCount);
          ParseResult.Verses[VerseCount - 1].Chapter := CurChapter;
          ParseResult.Verses[VerseCount - 1].Verse := CurVerse;
          ParseResult.Verses[VerseCount - 1].Content := Rest;
          Continue;
        end
        else if (Token = '\p') or (Token = '\s') or (Token = '\s5') or
                (Token = '\d') or (Token = '\ide') or (Token = '\toc1') or
                (Token = '\toc2') or (Token = '\toc3') or (Token = '\mt1') or
                (Token = '\mt2') then
        begin
          { Known structural markers — skip }
          Continue;
        end;
      end;

      { Non-marker line or continuation — append to last verse if any }
      if VerseCount > 0 then
        ParseResult.Verses[VerseCount - 1].Content :=
          ParseResult.Verses[VerseCount - 1].Content + ' ' + Trimmed;
    end;

    Result := ParseResult.BookID <> '';
    if not Result then
      ErrorMsg := 'No \id marker found in USFM file.';
  finally
    SL.Free;
  end;
end;

end.
