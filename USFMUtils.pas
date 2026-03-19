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

{ Render USFM text (with \v markers) as HTML with superscript verse numbers.
  Other markers are stripped. Suitable for read-mode display of translations. }
function RenderUSFMAsHtml(const USFMText: string): string;

{ Convert USX markup to HTML with styled paragraphs, verse badges,
  poetry indentation, Selah, footnotes, and section headings.
  ABadgeColor is the verse number badge background color as #RRGGBB. }
function UsxToHtml(const UsxText, ABadgeColor: string): string;

type
  TUSFMVerse = record
    Chapter: Integer;
    Verse: Integer;
    Content: string;   { raw text including \v marker }
  end;
  TUSFMVerseArray = array of TUSFMVerse;

  TUSFMParseWarning = record
    Line: Integer;       { 1-based line number (0 if not line-specific) }
    Col: Integer;        { 1-based column (0 if not applicable) }
    Msg: string;
  end;
  TUSFMParseWarningArray = array of TUSFMParseWarning;

  TUSFMParseResult = record
    BookID: string;      { from \id line }
    BookTitle: string;   { from \h or \mt }
    Verses: TUSFMVerseArray;
    Warnings: TUSFMParseWarningArray;
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

function UsxHtmlEscape(const S: string): string;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to Length(S) do
    case S[I] of
      '<': Result := Result + '&lt;';
      '>': Result := Result + '&gt;';
      '&': Result := Result + '&amp;';
      '"': Result := Result + '&quot;';
    else
      Result := Result + S[I];
    end;
end;

function ExtractXmlAttr(const Tag, AttrName: string): string;
{ Extract value of an attribute from an XML tag string, e.g.
  ExtractXmlAttr('<para style="q2">', 'style') = 'q2' }
var
  P, Q: Integer;
  Search: string;
begin
  Result := '';
  Search := AttrName + '="';
  P := Pos(Search, Tag);
  if P = 0 then Exit;
  P := P + Length(Search);
  Q := Pos('"', Tag, P);
  if Q = 0 then Exit;
  Result := Copy(Tag, P, Q - P);
end;

function UsxToHtml(const UsxText, ABadgeColor: string): string;
{ Walk through USX fragment text, emitting HTML for each element.
  Handles: <verse>, <para>, <char>, <note>, plain text. }
var
  S: string;
  P, TagStart, TagEnd: Integer;
  TagStr, TagName, Style, AttrVal: string;
  SelfClosing: Boolean;
  InPara: Boolean;
  FootnoteChar: string;
begin
  Result := '';
  S := UsxText;
  P := 1;
  InPara := False;
  FootnoteChar := '&#8224;'; { dagger U+2020 }

  while P <= Length(S) do
  begin
    if S[P] = '<' then
    begin
      { Find end of tag }
      TagStart := P;
      TagEnd := Pos('>', S, P);
      if TagEnd = 0 then
      begin
        { Malformed — emit rest as text }
        Result := Result + UsxHtmlEscape(Copy(S, P, Length(S) - P + 1));
        Break;
      end;
      TagStr := Copy(S, TagStart, TagEnd - TagStart + 1);
      SelfClosing := (TagEnd > 1) and (S[TagEnd - 1] = '/');
      P := TagEnd + 1;

      { Determine tag name }
      if Pos('</', TagStr) = 1 then
      begin
        { Closing tag }
        TagName := '';
        if Pos('</para>', TagStr) = 1 then
        begin
          if InPara then
          begin
            Result := Result + '</p>';
            InPara := False;
          end;
        end
        else if Pos('</char>', TagStr) = 1 then
          Result := Result + '</span>'
        else if Pos('</note>', TagStr) = 1 then
          { handled by note opening }
        ;
        Continue;
      end;

      { Opening/self-closing tag }
      if Pos('<verse', TagStr) = 1 then
      begin
        AttrVal := ExtractXmlAttr(TagStr, 'number');
        Result := Result + ' <span style="background-color:' + ABadgeColor +
          '; color:white; padding:1px 5px; font-weight:bold; ' +
          'font-size:80%;">' + UsxHtmlEscape(AttrVal) + '</span> ';
      end
      else if Pos('<para', TagStr) = 1 then
      begin
        Style := ExtractXmlAttr(TagStr, 'style');
        if SelfClosing then
        begin
          { Self-closing para — typically <para style="b"/> }
          if Style = 'b' then
            Result := Result + '<p style="margin:0.3em 0;">&nbsp;</p>'
          else if (Style = 'p') or (Style = 'm') then
            Result := Result + '<br>';
        end
        else
        begin
          { Close any open para first }
          if InPara then
            Result := Result + '</p>';
          InPara := True;

          if Style = 'q1' then
            Result := Result + '<p style="margin:0 0 0 2em;">'
          else if Style = 'q2' then
            Result := Result + '<p style="margin:0 0 0 3em;">'
          else if Style = 'q3' then
            Result := Result + '<p style="margin:0 0 0 4em;">'
          else if Style = 'b' then
          begin
            Result := Result + '<p style="margin:0.3em 0;">&nbsp;</p>';
            InPara := False;
          end
          else if Style = 's1' then
            Result := Result + '<p style="font-weight:bold; margin:0.5em 0 0.2em 0;">'
          else if Style = 's2' then
            Result := Result + '<p style="font-weight:bold; font-size:90%; margin:0.4em 0 0.2em 0;">'
          else if Style = 'r' then
            Result := Result + '<p style="font-style:italic; color:#606060; margin:0 0 0.3em 0;">'
          else if Style = 'd' then
            Result := Result + '<p style="font-style:italic; color:#606060; margin:0 0 0.3em 0;">'
          else if Style = 'm' then
            Result := Result + '<p style="margin:0;">'
          else if Style = 'pi1' then
            Result := Result + '<p style="margin:0 0 0 2em; text-indent:1em;">'
          else if Style = 'p' then
            Result := Result + '<p style="text-indent:1em; margin:0;">'
          else
            Result := Result + '<p style="margin:0;">';
        end;
      end
      else if Pos('<char', TagStr) = 1 then
      begin
        Style := ExtractXmlAttr(TagStr, 'style');
        if Style = 'qs' then
          Result := Result + '<span style="font-style:italic; color:#606060;">'
        else if Style = 'tl' then
          Result := Result + '<span style="font-style:italic;">'
        else if Style = 'nd' then
          Result := Result + '<span style="font-variant:small-caps;">'
        else if Style = 'wj' then
          Result := Result + '<span style="color:#CC0000;">'
        else if Style = 'add' then
          Result := Result + '<span style="font-style:italic;">'
        else if Style = 'bk' then
          Result := Result + '<span style="font-style:italic;">'
        else if Style = 'sc' then
          Result := Result + '<span style="font-variant:small-caps;">'
        else
          { Footnote-internal styles (ft, fr, fk, fq, fqa) are hidden
            since we collapse footnotes to a dagger indicator }
          Result := Result + '<span>';
      end
      else if Pos('<note', TagStr) = 1 then
      begin
        { Skip all content until </note> and show a footnote indicator }
        TagEnd := Pos('</note>', S, P);
        if TagEnd > 0 then
          P := TagEnd + Length('</note>')
        else
          P := Length(S) + 1;
        Result := Result + ' <span style="background-color:#FF8040; color:white;' +
          ' padding:1px 3px; font-weight:bold; font-size:80%;">' +
          FootnoteChar + '</span> ';
      end;
      { Ignore other tags (ref, etc.) }
    end
    else
    begin
      { Plain text — collect until next tag }
      TagStart := P;
      while (P <= Length(S)) and (S[P] <> '<') do
        Inc(P);
      AttrVal := Copy(S, TagStart, P - TagStart);
      { Skip pure whitespace between tags }
      if Trim(AttrVal) <> '' then
        Result := Result + UsxHtmlEscape(AttrVal);
    end;
  end;

  if InPara then
    Result := Result + '</p>';
end;

function RenderUSFMAsHtml(const USFMText: string): string;
var
  P, Len, NumStart: Integer;
  Ch: Char;
  NumStr: string;
begin
  Result := '';
  P := 1;
  Len := Length(USFMText);

  while P <= Len do
  begin
    Ch := USFMText[P];

    if (Ch = '\') and (P + 1 <= Len) then
    begin
      { Check for \v marker }
      if (USFMText[P + 1] = 'v') and (P + 2 <= Len) and (USFMText[P + 2] = ' ') then
      begin
        { Extract verse number }
        P := P + 3;
        NumStart := P;
        while (P <= Len) and (USFMText[P] in ['0'..'9', '-']) do
          Inc(P);
        NumStr := Copy(USFMText, NumStart, P - NumStart);
        if NumStr <> '' then
          Result := Result + '<sup style="color:#5C6BC0;font-weight:bold;' +
            'font-size:75%;margin:0 2px;">' + NumStr + '</sup>';
        { Skip space after number }
        if (P <= Len) and (USFMText[P] = ' ') then
          Inc(P);
        Continue;
      end
      else
      begin
        { Other marker — skip marker name, keep any argument text }
        Inc(P); { skip backslash }
        while (P <= Len) and (USFMText[P] in ['a'..'z', 'A'..'Z', '0'..'9', '*']) do
          Inc(P);
        { Skip space after marker }
        if (P <= Len) and (USFMText[P] = ' ') then
          Inc(P);
        Continue;
      end;
    end
    else
    begin
      { Plain text — HTML-escape }
      case Ch of
        '<': Result := Result + '&lt;';
        '>': Result := Result + '&gt;';
        '&': Result := Result + '&amp;';
      else
        Result := Result + Ch;
      end;
      Inc(P);
    end;
  end;
end;

{ ----- Fault-tolerant USFM tokenizer/parser -----

  Scans character-by-character for \marker patterns. Handles multiple
  markers per line, stray/duplicate markers, missing numbers, typos
  like /v or \c., and inline footnotes. Produces a chapter/verse
  structure even from badly malformed input, logging warnings for
  every anomaly encountered. }

type
  TUSFMTokenKind = (
    tkId, tkIde, tkH, tkToc, tkMt, tkCl,
    tkChapter, tkVerse, tkParagraph, tkBlank,
    tkFootnoteOpen, tkFootnoteClose,
    tkSection, tkOther, tkText
  );

  TUSFMToken = record
    Kind: TUSFMTokenKind;
    Marker: string;   { e.g. 'c', 'v', 'p', 'f', 'id' }
    Arg: string;      { text after marker+space, up to next marker }
    Line: Integer;    { source line (1-based) }
    Col: Integer;     { source column (1-based) }
  end;
  TUSFMTokenArray = array of TUSFMToken;

function IsUSFMMarkerChar(C: Char): Boolean; inline;
begin
  Result := C in ['a'..'z', 'A'..'Z', '0'..'9'];
end;

function ClassifyMarker(const Marker: string): TUSFMTokenKind;
var
  M: string;
begin
  M := LowerCase(Marker);
  if M = 'id' then Result := tkId
  else if M = 'ide' then Result := tkIde
  else if M = 'h' then Result := tkH
  else if (M = 'toc1') or (M = 'toc2') or (M = 'toc3') or
          (M = 'toca1') or (M = 'toca2') or (M = 'toca3') then Result := tkToc
  else if (M = 'mt') or (M = 'mt1') or (M = 'mt2') or (M = 'mt3') then Result := tkMt
  else if M = 'cl' then Result := tkCl
  else if M = 'c' then Result := tkChapter
  else if M = 'v' then Result := tkVerse
  else if (M = 'p') or (M = 'po') or (M = 'pr') or (M = 'pm') or
          (M = 'pmo') or (M = 'pms') or (M = 'pi') or (M = 'pi1') or
          (M = 'pi2') or (M = 'pi3') or (M = 'pc') or (M = 'm') or
          (M = 'q') or (M = 'q1') or (M = 'q2') or (M = 'q3') or
          (M = 'q4') or (M = 'qr') or (M = 'qm') or (M = 'qm1') or
          (M = 'qm2') or (M = 'li') or (M = 'li1') or (M = 'li2') or
          (M = 'tr') then Result := tkParagraph
  else if M = 'b' then Result := tkBlank
  else if (M = 'f') or (M = 'fe') or (M = 'x') then Result := tkFootnoteOpen
  else if (M = 'f*') or (M = 'fe*') or (M = 'x*') then Result := tkFootnoteClose
  else if (M = 's') or (M = 's1') or (M = 's2') or (M = 's3') or
          (M = 's4') or (M = 's5') or (M = 'd') or (M = 'r') or
          (M = 'ms') or (M = 'ms1') or (M = 'ms2') or (M = 'mr') or
          (M = 'sp') then Result := tkSection
  else Result := tkOther;
end;

{ Tokenize raw USFM text into a flat token array.
  Handles:
  - Multiple markers per line
  - \marker with no space before next marker
  - Closing markers like \f* (star suffix)
  - Stray punctuation after markers (e.g. \c.)
  - Forward-slash typos (/v)  }
function TokenizeUSFM(const Text: string; out Warnings: TUSFMParseWarningArray): TUSFMTokenArray;
var
  Tokens: TUSFMTokenArray;
  TokenCount, WarnCount: Integer;
  P, Len, MarkerStart, MarkerEnd, ArgStart, ArgEnd: Integer;
  CurLine, CurCol, LineStart: Integer;
  Marker, Arg: string;
  Ch: Char;
  InFootnote: Boolean;

  procedure AddToken(AKind: TUSFMTokenKind; const AMarker, AArg: string;
    ALine, ACol: Integer);
  begin
    if TokenCount >= Length(Tokens) then
      SetLength(Tokens, Length(Tokens) + 256);
    Tokens[TokenCount].Kind := AKind;
    Tokens[TokenCount].Marker := AMarker;
    Tokens[TokenCount].Arg := AArg;
    Tokens[TokenCount].Line := ALine;
    Tokens[TokenCount].Col := ACol;
    Inc(TokenCount);
  end;

  procedure AddWarning(ALine, ACol: Integer; const AMsg: string);
  begin
    if WarnCount >= Length(Warnings) then
      SetLength(Warnings, Length(Warnings) + 32);
    Warnings[WarnCount].Line := ALine;
    Warnings[WarnCount].Col := ACol;
    Warnings[WarnCount].Msg := AMsg;
    Inc(WarnCount);
  end;

  procedure TrackPosition;
  begin
    while (LineStart < P) do
    begin
      if Text[LineStart] = #10 then
      begin
        Inc(CurLine);
        CurCol := 1;
      end
      else
        Inc(CurCol);
      Inc(LineStart);
    end;
  end;

begin
  SetLength(Tokens, 256);
  SetLength(Warnings, 32);
  TokenCount := 0;
  WarnCount := 0;
  Len := Length(Text);
  P := 1;
  CurLine := 1;
  CurCol := 1;
  LineStart := 1;
  InFootnote := False;

  while P <= Len do
  begin
    Ch := Text[P];

    { Detect marker: backslash (or forward-slash typo) followed by letter }
    if ((Ch = '\') or (Ch = '/')) and (P + 1 <= Len) and
       (Text[P + 1] in ['a'..'z', 'A'..'Z']) then
    begin
      TrackPosition;

      if Ch = '/' then
        AddWarning(CurLine, CurCol,
          'Forward slash used instead of backslash — treating as marker');

      MarkerStart := P + 1;
      MarkerEnd := MarkerStart;
      while (MarkerEnd <= Len) and IsUSFMMarkerChar(Text[MarkerEnd]) do
        Inc(MarkerEnd);

      { Check for closing marker star: \f* }
      if (MarkerEnd <= Len) and (Text[MarkerEnd] = '*') then
        Inc(MarkerEnd);

      Marker := Copy(Text, MarkerStart, MarkerEnd - MarkerStart);

      { Skip stray punctuation after marker (e.g. \c. or \c,) }
      if (MarkerEnd <= Len) and (Text[MarkerEnd] in ['.', ',', ';', ':']) and
         (Marker <> '') and (Pos('*', Marker) = 0) then
      begin
        AddWarning(CurLine, CurCol,
          'Stray "' + Text[MarkerEnd] + '" after \' + Marker + ' — ignored');
        Inc(MarkerEnd);
      end;

      { Skip whitespace after marker }
      while (MarkerEnd <= Len) and (Text[MarkerEnd] in [' ', #9]) do
        Inc(MarkerEnd);

      { Collect argument text until next marker or end of line }
      ArgStart := MarkerEnd;
      ArgEnd := ArgStart;
      while (ArgEnd <= Len) do
      begin
        if (Text[ArgEnd] = '\') or
           ((Text[ArgEnd] = '/') and (ArgEnd + 1 <= Len) and
            (Text[ArgEnd + 1] in ['a'..'z', 'A'..'Z'])) then
          Break;
        if Text[ArgEnd] = #10 then
        begin
          Inc(ArgEnd);
          Break;
        end;
        Inc(ArgEnd);
      end;

      Arg := Trim(Copy(Text, ArgStart, ArgEnd - ArgStart));
      P := ArgEnd;

      { Track footnote state }
      if ClassifyMarker(Marker) = tkFootnoteOpen then
        InFootnote := True
      else if ClassifyMarker(Marker) = tkFootnoteClose then
        InFootnote := False;

      AddToken(ClassifyMarker(Marker), Marker, Arg, CurLine, CurCol);
    end
    else if Ch in [#10, #13] then
    begin
      { Line break — skip }
      if (Ch = #13) and (P + 1 <= Len) and (Text[P + 1] = #10) then
        Inc(P);
      Inc(P);
      Inc(CurLine);
      CurCol := 1;
      LineStart := P;
    end
    else
    begin
      { Plain text — collect until next marker or line break }
      TrackPosition;
      ArgStart := P;
      while (P <= Len) and not (Text[P] in ['\', '/', #10, #13]) do
      begin
        { Forward slash is only a marker if followed by letter }
        if (Text[P] = '/') then
        begin
          if (P + 1 <= Len) and (Text[P + 1] in ['a'..'z', 'A'..'Z']) then
            Break;
        end;
        Inc(P);
      end;
      Arg := Trim(Copy(Text, ArgStart, P - ArgStart));
      if Arg <> '' then
        AddToken(tkText, '', Arg, CurLine, CurCol);
    end;
  end;

  SetLength(Tokens, TokenCount);
  SetLength(Warnings, WarnCount);
  Result := Tokens;
end;

{ Build chapter/verse structure from token array }
function ParseUSFMFile(const FilePath: string; out ParseResult: TUSFMParseResult;
  out ErrorMsg: string): Boolean;
var
  SL: TStringList;
  FullText: string;
  Tokens: TUSFMTokenArray;
  TokenWarnings: TUSFMParseWarningArray;
  I, CurChapter, CurVerse, VerseCount, WarnCount: Integer;
  Tok: TUSFMToken;
  NumStr, VerseText: string;
  SpacePos, Num: Integer;
  SeenChapter: Integer;  { track last valid \c number to detect duplicates }
  InFootnote: Boolean;
  FootnoteText: string;

  procedure AddWarning(ALine, ACol: Integer; const AMsg: string);
  begin
    if WarnCount >= Length(ParseResult.Warnings) then
      SetLength(ParseResult.Warnings, Length(ParseResult.Warnings) + 32);
    ParseResult.Warnings[WarnCount].Line := ALine;
    ParseResult.Warnings[WarnCount].Col := ACol;
    ParseResult.Warnings[WarnCount].Msg := AMsg;
    Inc(WarnCount);
  end;

  procedure EmitVerse(AChapter, AVerse: Integer; const AContent: string);
  begin
    Inc(VerseCount);
    if VerseCount > Length(ParseResult.Verses) then
      SetLength(ParseResult.Verses, Length(ParseResult.Verses) + 128);
    ParseResult.Verses[VerseCount - 1].Chapter := AChapter;
    ParseResult.Verses[VerseCount - 1].Verse := AVerse;
    ParseResult.Verses[VerseCount - 1].Content := AContent;
  end;

  procedure AppendToLastVerse(const AText: string);
  begin
    if VerseCount > 0 then
      ParseResult.Verses[VerseCount - 1].Content :=
        ParseResult.Verses[VerseCount - 1].Content + ' ' + AText;
  end;

begin
  Result := False;
  ParseResult := Default(TUSFMParseResult);
  ErrorMsg := '';
  WarnCount := 0;

  if not FileExists(FilePath) then
  begin
    ErrorMsg := 'File not found: ' + FilePath;
    Exit;
  end;

  SL := TStringList.Create;
  try
    SL.LoadFromFile(FilePath);
    FullText := SL.Text;
  finally
    SL.Free;
  end;

  Tokens := TokenizeUSFM(FullText, TokenWarnings);

  { Copy tokenizer warnings }
  SetLength(ParseResult.Warnings, Length(TokenWarnings) + 32);
  for I := 0 to Length(TokenWarnings) - 1 do
  begin
    ParseResult.Warnings[I] := TokenWarnings[I];
    Inc(WarnCount);
  end;

  CurChapter := 0;
  CurVerse := 0;
  VerseCount := 0;
  SeenChapter := -1;
  InFootnote := False;

  for I := 0 to Length(Tokens) - 1 do
  begin
    Tok := Tokens[I];

    case Tok.Kind of
      tkId:
      begin
        { \id BOOK rest-of-line }
        SpacePos := Pos(' ', Tok.Arg);
        if SpacePos > 0 then
          ParseResult.BookID := Trim(Copy(Tok.Arg, 1, SpacePos - 1))
        else
          ParseResult.BookID := Trim(Tok.Arg);
      end;

      tkH:
      begin
        if ParseResult.BookTitle = '' then
          ParseResult.BookTitle := Tok.Arg;
      end;

      tkMt:
      begin
        if ParseResult.BookTitle = '' then
          ParseResult.BookTitle := Tok.Arg;
      end;

      tkChapter:
      begin
        { Extract chapter number from arg }
        NumStr := Tok.Arg;
        { Strip anything after the number (e.g. "\c 1 \c \v 1 text") }
        SpacePos := 1;
        while (SpacePos <= Length(NumStr)) and
              (NumStr[SpacePos] in ['0'..'9']) do
          Inc(SpacePos);
        NumStr := Copy(NumStr, 1, SpacePos - 1);

        Num := StrToIntDef(NumStr, 0);
        if Num = 0 then
        begin
          { Bare \c with no valid number — skip }
          AddWarning(Tok.Line, Tok.Col,
            '\c marker with no valid chapter number — ignored');
          Continue;
        end;

        if Num = SeenChapter then
        begin
          { Duplicate chapter marker (e.g. \c 01 then \c 1) — skip }
          AddWarning(Tok.Line, Tok.Col,
            'Duplicate \c ' + IntToStr(Num) + ' — ignored');
          Continue;
        end;

        CurChapter := Num;
        SeenChapter := Num;
        CurVerse := 0;
      end;

      tkVerse:
      begin
        if CurChapter = 0 then
        begin
          { Verse before any chapter — assume chapter 1 }
          CurChapter := 1;
          SeenChapter := 1;
          AddWarning(Tok.Line, Tok.Col,
            '\v before any \c marker — assuming chapter 1');
        end;

        { Extract verse number }
        NumStr := '';
        SpacePos := 1;
        while (SpacePos <= Length(Tok.Arg)) and
              (Tok.Arg[SpacePos] in ['0'..'9', '-']) do
          Inc(SpacePos);
        NumStr := Copy(Tok.Arg, 1, SpacePos - 1);

        { Handle verse ranges like "1-3" — take the first number }
        if Pos('-', NumStr) > 0 then
          NumStr := Copy(NumStr, 1, Pos('-', NumStr) - 1);

        Num := StrToIntDef(NumStr, 0);
        if Num = 0 then
        begin
          AddWarning(Tok.Line, Tok.Col,
            '\v marker with no valid verse number — ignored');
          { Append arg text to previous verse if any }
          VerseText := Trim(Copy(Tok.Arg, SpacePos, MaxInt));
          if VerseText <> '' then
            AppendToLastVerse(VerseText);
          Continue;
        end;

        CurVerse := Num;
        VerseText := Trim(Copy(Tok.Arg, SpacePos, MaxInt));
        EmitVerse(CurChapter, CurVerse,
          '\v ' + IntToStr(CurVerse) + ' ' + VerseText);
      end;

      tkFootnoteOpen:
      begin
        InFootnote := True;
        FootnoteText := '\f ' + Tok.Arg;
      end;

      tkFootnoteClose:
      begin
        if InFootnote then
        begin
          FootnoteText := FootnoteText + ' \f*';
          { Attach footnote to current verse }
          AppendToLastVerse(FootnoteText);
          InFootnote := False;
        end;
      end;

      tkBlank:
      begin
        { \b — blank line marker used inline is a common error; skip it }
        if Tok.Arg <> '' then
        begin
          AddWarning(Tok.Line, Tok.Col,
            '\b marker has text content — treating as verse continuation');
          AppendToLastVerse(Tok.Arg);
        end;
      end;

      tkParagraph, tkSection, tkCl:
      begin
        { Structural markers — ignore, but if they have text that looks
          like verse content (after all inline \v have been extracted by
          the tokenizer), keep it }
      end;

      tkText:
      begin
        if InFootnote then
          FootnoteText := FootnoteText + ' ' + Tok.Arg
        else
          AppendToLastVerse(Tok.Arg);
      end;

      tkIde, tkToc:
      begin
        { Header markers — skip }
      end;

      tkOther:
      begin
        { Unknown marker — warn and pass through text }
        AddWarning(Tok.Line, Tok.Col,
          'Unknown marker \' + Tok.Marker + ' — passed through');
        if InFootnote then
          FootnoteText := FootnoteText + ' \' + Tok.Marker + ' ' + Tok.Arg
        else if Tok.Arg <> '' then
          AppendToLastVerse('\' + Tok.Marker + ' ' + Tok.Arg);
      end;
    end;
  end;

  SetLength(ParseResult.Verses, VerseCount);
  SetLength(ParseResult.Warnings, WarnCount);

  Result := ParseResult.BookID <> '';
  if not Result then
    ErrorMsg := 'No \id marker found in USFM file.';
end;

end.
