{$mode objfpc}{$H+}
unit USFMRenderer;

{ Convert USFM/USX text to CGE-label-compatible rich text.

  CGE's TCastleLabel understands a small HTML subset:
    <b>...</b>          bold
    <i>...</i>          italic
    <font color="#RRGGBB">...</font>   inline color
    <font size="N">...</font>          HTML size 1-7
    <small>...</small>  smaller font
    LineEnding          paragraph separator

  Markers handled:
    \v N          verse number (coloured inline tag)
    \p \m         paragraph break
    \b            blank line (double newline)
    \s5 \s \ms    section heading (bold)
    \d            descriptive heading / psalm superscription (italic)
    \q \q1        poetry line (2-space indent)
    \q2           poetry line (4-space indent)
    \q3 \q4       poetry line (6-space indent)
    \add..\add*   added text (italic)
    \nd..\nd*     divine name (bold)
    \f..\f*       footnote (stripped entirely)
    \x..\x*       cross-reference (stripped entirely)
    All other \markers are stripped; their following text is kept.

  UsxToRichText first converts USX→USFM via USFMUtils.UsxToPlainText,
  then calls USFMToRichText.
}

interface

function USFMToRichText(const USFMText, VerseColor: string): string;
function UsxToRichText(const UsxText, VerseColor: string): string;

implementation

uses
  SysUtils, Classes,
  USFMUtils;  { UsxToPlainText }

{ ── helpers ────────────────────────────────────────────────────────────────── }

function EscapeRichText(const S: string): string;
var
  I: Integer;
  C: Char;
begin
  Result := '';
  for I := 1 to Length(S) do
  begin
    C := S[I];
    case C of
      '<': Result := Result + '&lt;';
      '>': Result := Result + '&gt;';
      '&': Result := Result + '&amp;';
    else
      Result := Result + C;
    end;
  end;
end;

{ Return the marker word starting at P+1 (after the backslash) and advance P
  past the marker word and any single trailing space. }
function ParseMarker(const S: string; var P: Integer): string;
var
  Start: Integer;
begin
  Start := P;
  while (P <= Length(S)) and (S[P] in ['a'..'z', 'A'..'Z', '0'..'9', '+', '-', '*']) do
    Inc(P);
  Result := LowerCase(Copy(S, Start, P - Start));
  { skip single trailing space }
  if (P <= Length(S)) and (S[P] = ' ') then
    Inc(P);
end;

{ Skip from current P to past \marker* end-marker. }
procedure SkipToEndMarker(const S: string; const Marker: string; var P: Integer);
var
  EndTag: string;
  Pos_: Integer;
begin
  EndTag := '\' + Marker + '*';
  Pos_ := Pos(EndTag, S, P);
  if Pos_ > 0 then
    P := Pos_ + Length(EndTag)
  else
    P := Length(S) + 1;
end;

{ ── main converter ─────────────────────────────────────────────────────────── }

function USFMToRichText(const USFMText, VerseColor: string): string;
var
  Lines: TStringList;
  I, J: Integer;
  Line, Marker, Arg: string;
  P, LineLen: Integer;
  InFootnote, InCrossRef: Boolean;
  NeedNewline: Boolean;
  Chunk: string;
begin
  Result := '';
  InFootnote  := False;
  InCrossRef  := False;
  NeedNewline := False;

  Lines := TStringList.Create;
  try
    Lines.Text := USFMText;

    for I := 0 to Lines.Count - 1 do
    begin
      Line := TrimRight(Lines[I]);
      if Line = '' then
      begin
        { Blank input line → blank separator in output }
        Result := Result + LineEnding;
        NeedNewline := False;
        Continue;
      end;

      J := 1;
      LineLen := Length(Line);

      { Each line may start with a paragraph-level marker OR be a
        continuation of the previous verse. }
      while J <= LineLen do
      begin
        if (Line[J] = '\') and (J < LineLen) then
        begin
          Inc(J); { skip backslash }
          Marker := ParseMarker(Line, J);
          { remaining text after the marker word }

          { Skip-until-end markers }
          if (Marker = 'f') or (Marker = 'fe') then
          begin
            InFootnote := True;
            SkipToEndMarker(Line, 'f', J);
            InFootnote := False;
            Continue;
          end;
          if Marker = 'x' then
          begin
            InCrossRef := True;
            SkipToEndMarker(Line, 'x', J);
            InCrossRef := False;
            Continue;
          end;

          { Paragraph break markers }
          if (Marker = 'p') or (Marker = 'm') or (Marker = 'pi') or
             (Marker = 'mi') or (Marker = 'pc') or (Marker = 'pmo') or
             (Marker = 'pm') or (Marker = 'cls') then
          begin
            if NeedNewline then
              Result := Result + LineEnding;
            NeedNewline := False;
            Continue;
          end;

          if Marker = 'b' then
          begin
            Result := Result + LineEnding;
            NeedNewline := False;
            Continue;
          end;

          { Verse number: \v N }
          if Marker = 'v' then
          begin
            { Parse verse number (may be range like 3-4) }
            Arg := '';
            while (J <= LineLen) and (Line[J] in ['0'..'9', '-']) do
            begin
              Arg := Arg + Line[J];
              Inc(J);
            end;
            { Skip space after number }
            if (J <= LineLen) and (Line[J] = ' ') then
              Inc(J);
            if NeedNewline then
              Result := Result + LineEnding;
            Result := Result +
              '<font color="' + VerseColor + '"><b>' + Arg + '</b></font> ';
            NeedNewline := True;
            Continue;
          end;

          { Section headings }
          if (Marker = 's') or (Marker = 's1') or (Marker = 's2') or
             (Marker = 's3') or (Marker = 's4') or (Marker = 's5') or
             (Marker = 'ms') or (Marker = 'ms1') or (Marker = 'mr') or
             (Marker = 'r') then
          begin
            if NeedNewline then
              Result := Result + LineEnding;
            { rest of line is heading text }
            Arg := EscapeRichText(TrimRight(Copy(Line, J, LineLen)));
            if Arg <> '' then
              Result := Result + '<b>' + Arg + '</b>';
            Result := Result + LineEnding;
            NeedNewline := False;
            J := LineLen + 1; { consumed rest of line }
            Continue;
          end;

          { Descriptive heading / psalm superscription }
          if (Marker = 'd') then
          begin
            if NeedNewline then
              Result := Result + LineEnding;
            Arg := EscapeRichText(TrimRight(Copy(Line, J, LineLen)));
            if Arg <> '' then
              Result := Result + '<i>' + Arg + '</i>';
            Result := Result + LineEnding;
            NeedNewline := False;
            J := LineLen + 1;
            Continue;
          end;

          { Poetry lines }
          if (Marker = 'q') or (Marker = 'q1') or
             (Marker = 'qc') or (Marker = 'qa') then
          begin
            if NeedNewline then
              Result := Result + LineEnding;
            Chunk := EscapeRichText(TrimRight(Copy(Line, J, LineLen)));
            if Chunk <> '' then
              Result := Result + '  ' + Chunk;
            NeedNewline := True;
            J := LineLen + 1;
            Continue;
          end;

          if (Marker = 'q2') or (Marker = 'qm') or (Marker = 'qm1') then
          begin
            if NeedNewline then
              Result := Result + LineEnding;
            Chunk := EscapeRichText(TrimRight(Copy(Line, J, LineLen)));
            if Chunk <> '' then
              Result := Result + '    ' + Chunk;
            NeedNewline := True;
            J := LineLen + 1;
            Continue;
          end;

          if (Marker = 'q3') or (Marker = 'q4') or (Marker = 'qm2') then
          begin
            if NeedNewline then
              Result := Result + LineEnding;
            Chunk := EscapeRichText(TrimRight(Copy(Line, J, LineLen)));
            if Chunk <> '' then
              Result := Result + '      ' + Chunk;
            NeedNewline := True;
            J := LineLen + 1;
            Continue;
          end;

          { Inline character style end-markers }
          if (Length(Marker) > 0) and (Marker[Length(Marker)] = '*') then
          begin
            { End of add/nd/wj/etc. — handled by the open handler; just continue }
            Continue;
          end;

          { Inline character styles }
          if Marker = 'add' then
          begin
            { Collect up to \add* }
            P := J;
            while (J <= LineLen) and not ((Line[J] = '\') and
              (Pos('\add*', Line, J) = J)) do
              Inc(J);
            Arg := EscapeRichText(Copy(Line, P, J - P));
            Result := Result + '<i>' + Arg + '</i>';
            if (J <= LineLen) then
              J := J + Length('\add*');
            Continue;
          end;

          if Marker = 'nd' then
          begin
            P := J;
            while (J <= LineLen) and not ((Line[J] = '\') and
              (Pos('\nd*', Line, J) = J)) do
              Inc(J);
            Arg := EscapeRichText(Copy(Line, P, J - P));
            Result := Result + '<b>' + Arg + '</b>';
            if (J <= LineLen) then
              J := J + Length('\nd*');
            Continue;
          end;

          { Catch-all: strip marker, keep following text on the same line }
          { (e.g. \pi, \li, \sp, \wj, \k, \tl, etc.) }
          { Continue and let the next loop iteration process remaining text }
          Continue;
        end
        else
        begin
          { Plain text character — collect a run of plain text }
          P := J;
          while (J <= LineLen) and (Line[J] <> '\') do
            Inc(J);
          Chunk := Copy(Line, P, J - P);
          if Chunk <> '' then
          begin
            Result := Result + EscapeRichText(Chunk);
            NeedNewline := True;
          end;
        end;
      end; { while J <= LineLen }

      { End of input line — add a soft newline between lines of the same verse }
      if NeedNewline and (I < Lines.Count - 1) and
         (TrimRight(Lines[I + 1]) <> '') then
      begin
        { Only emit newline if next line continues verse content (not a new
          paragraph marker). This preserves flowing verse text. }
        if (Length(Lines[I + 1]) > 0) and (Lines[I + 1][1] <> '\') then
        begin
          Result := Result + LineEnding;
          NeedNewline := False;
        end;
      end;
    end; { for I }

  finally
    Lines.Free;
  end;

  Result := TrimRight(Result);
end;

function UsxToRichText(const UsxText, VerseColor: string): string;
begin
  Result := USFMToRichText(UsxToPlainText(UsxText), VerseColor);
end;

end.
