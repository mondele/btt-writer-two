{$mode objfpc}{$H+}
unit AppState;

{ Centralised application state record.
  All screen transitions are driven by mutating this record,
  then switching the active TCastleView. }

interface

type
  TAppScreen = (asHome, asEditor);

  TAppState = record
    Screen: TAppScreen;
    ProjectTitle: String;
    ChapterNum: Integer;
    EditingChunkIndex: Integer; { -1 = none }
  end;

var
  GAppState: TAppState;

implementation

initialization
  GAppState.Screen := asHome;
  GAppState.ProjectTitle := 'Psalm 23 — English ULB';
  GAppState.ChapterNum := 23;
  GAppState.EditingChunkIndex := -1;

end.
