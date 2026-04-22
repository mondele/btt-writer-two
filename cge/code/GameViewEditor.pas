{$mode objfpc}{$H+}
unit GameViewEditor;

{ Editor view — Phase 0 stub.
  Displays the project title and a "Back" button.
  Full chunk rendering and editing arrive in Phase 2. }

interface

uses
  Classes,
  CastleUIControls, CastleControls, CastleColors, CastleVectors,
  CGEViewBase;

type
  TViewEditor = class(TCGEViewBase)
  private
    FHeader  : TCastleRectangleControl;
    FBackBtn : TCastleButton;
    FTitleLbl: TCastleLabel;
    FBodyLbl : TCastleLabel;

    procedure ClickBack(Sender: TObject);
    procedure BuildUI;
  public
    procedure Start; override;
    procedure Resize; override;
    procedure OnThemeChange; override;
  end;

var
  ViewEditor: TViewEditor;

implementation

uses
  SysUtils,
  AppState, BTTTheme,
  GameViewHome;

const
  HeaderH = 60;

{ TViewEditor }

procedure TViewEditor.Start;
begin
  inherited;
  ApplyBackground;
  BuildUI;
end;

procedure TViewEditor.BuildUI;
var
  Pal: TBTTPalette;
begin
  Pal := P;

  { Header }
  FHeader := TCastleRectangleControl.Create(FreeAtStop);
  FHeader.Color := Pal.HeaderBg;
  FHeader.Height := HeaderH;
  FHeader.WidthFraction := 1;
  FHeader.Anchor(vpTop, vpTop);
  InsertFront(FHeader);

  FBackBtn := TCastleButton.Create(FreeAtStop);
  FBackBtn.Caption := '< Home';
  FBackBtn.FontSize := 14;
  FBackBtn.OnClick := @ClickBack;
  FBackBtn.Anchor(hpLeft, hpLeft, 12);
  FBackBtn.Anchor(vpMiddle, vpMiddle);
  FHeader.InsertFront(FBackBtn);

  FTitleLbl := TCastleLabel.Create(FreeAtStop);
  FTitleLbl.Caption := GAppState.Editor.ProjectTitle;
  FTitleLbl.Color := Pal.HeaderText;
  FTitleLbl.FontSize := 18;
  FTitleLbl.Anchor(hpMiddle, hpMiddle);
  FTitleLbl.Anchor(vpMiddle, vpMiddle);
  FHeader.InsertFront(FTitleLbl);

  { Phase placeholder }
  FBodyLbl := TCastleLabel.Create(FreeAtStop);
  FBodyLbl.Caption :=
    'Editor — Phase 2' + LineEnding + LineEnding +
    'Project:  ' + GAppState.Editor.ProjectDir + LineEnding +
    'Book:     ' + GAppState.Editor.BookCode + LineEnding +
    'Language: ' + GAppState.Editor.TargetLangCode;
  FBodyLbl.Color := Pal.TextSecondary;
  FBodyLbl.FontSize := 14;
  FBodyLbl.Alignment := hpMiddle;
  FBodyLbl.Anchor(hpMiddle, hpMiddle);
  FBodyLbl.Anchor(vpMiddle, vpMiddle);
  InsertFront(FBodyLbl);
end;

procedure TViewEditor.ClickBack(Sender: TObject);
begin
  GAppState.Screen := asHome;
  ResetEditorState;
  Container.View := ViewHome;
end;

procedure TViewEditor.Resize;
begin
  inherited;
end;

procedure TViewEditor.OnThemeChange;
begin
  if Container <> nil then
    Container.View := Self;
end;

end.
