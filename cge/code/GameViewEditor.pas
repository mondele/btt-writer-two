{$mode objfpc}{$H+}
unit GameViewEditor;

{ Editor view — Phase 0/1 stub.
  Full chunk rendering and editing arrive in Phase 4/5.
  Currently shows the project header with a functioning Back button. }

interface

uses
  Classes,
  CastleUIControls, CastleControls, CastleColors,
  CGEViewBase, BTTHeader;

type
  TViewEditor = class(TCGEViewBase)
  private
    FHeader  : TBTTHeader;
    FBackBtn : TCastleButton;
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
  SysUtils, CastleVectors,
  AppState, BTTTheme,
  GameViewHome;

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

  FHeader := TBTTHeader.Create(FreeAtStop, Pal);
  FHeader.SetTitle(GAppState.Editor.ProjectTitle);
  InsertFront(FHeader);

  FBackBtn := TCastleButton.Create(FreeAtStop);
  FBackBtn.Caption  := '< Home';
  FBackBtn.FontSize := 14;
  FBackBtn.OnClick  := @ClickBack;
  FHeader.AddLeft(FBackBtn);

  FBodyLbl := TCastleLabel.Create(FreeAtStop);
  FBodyLbl.Caption :=
    'Editor — Phase 4/5' + LineEnding + LineEnding +
    'Project:  ' + GAppState.Editor.ProjectDir  + LineEnding +
    'Book:     ' + GAppState.Editor.BookCode     + LineEnding +
    'Language: ' + GAppState.Editor.TargetLangCode;
  FBodyLbl.Color     := Pal.TextSecondary;
  FBodyLbl.FontSize  := 14;
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
var
  W: Single;
begin
  inherited;
  if FHeader = nil then Exit;
  W := EffectiveWidth;
  FHeader.Translation := Vector2(0, EffectiveHeight - BTT_HEADER_H);
  FHeader.Width       := W;
  FHeader.Height      := BTT_HEADER_H;
end;

procedure TViewEditor.OnThemeChange;
begin
  if Container <> nil then
    Container.View := Self;
end;

end.
