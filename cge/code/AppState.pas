{$mode objfpc}{$H+}
unit AppState;

{ Centralised application state.
  All screen transitions are driven by mutating this record, then
  switching the active TCastleView — no ShowModal, no form stacks. }

interface

type
  TAppScreen = (asHome, asEditor);

  TEditorViewMode = (evmRead, evmBlindEdit, evmEditReview);

  TEditorState = record
    ProjectDir   : String;
    ProjectTitle : String;
    BookCode     : String;
    SourceLangCode: String;
    TargetLangCode: String;
    ChapterIndex : Integer;  { 0-based index into source chapter list }
    ChunkIndex   : Integer;  { -1 = none selected }
    ViewMode     : TEditorViewMode;
    IsRTL        : Boolean;
  end;

  TAppState = record
    Screen   : TAppScreen;
    UserName : String;        { display name of logged-in user }
    IsLocal  : Boolean;       { True = local profile, not server account }
    Editor   : TEditorState;
  end;

var
  GAppState: TAppState;

procedure ResetEditorState;

implementation

procedure ResetEditorState;
begin
  GAppState.Editor.ProjectDir    := '';
  GAppState.Editor.ProjectTitle  := '';
  GAppState.Editor.BookCode      := '';
  GAppState.Editor.SourceLangCode := '';
  GAppState.Editor.TargetLangCode := '';
  GAppState.Editor.ChapterIndex  := 0;
  GAppState.Editor.ChunkIndex    := -1;
  GAppState.Editor.ViewMode      := evmEditReview;
  GAppState.Editor.IsRTL         := False;
end;

initialization
  GAppState.Screen   := asHome;
  GAppState.UserName := '';
  GAppState.IsLocal  := True;
  ResetEditorState;

end.
