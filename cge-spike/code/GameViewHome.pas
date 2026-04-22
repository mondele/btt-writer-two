{$mode objfpc}{$H+}
unit GameViewHome;

{ Home screen.  Shows a project list placeholder and a button that
  transitions to the editor by mutating AppState and switching views. }

interface

uses
  Classes,
  CastleUIControls, CastleControls, CastleColors, CastleKeysMouse;

type
  TViewHome = class(TCastleView)
  private
    FHeader    : TCastleRectangleControl;
    FTitleLbl  : TCastleLabel;
    FContent   : TCastleRectangleControl;
    FWelcomeLbl: TCastleLabel;
    FOpenBtn   : TCastleButton;
    FUserLbl   : TCastleLabel;

    procedure ClickOpen(Sender: TObject);
    procedure BuildUI;
  public
    procedure Start; override;
    procedure Resize; override;
  end;

var
  ViewHome: TViewHome;

implementation

uses
  SysUtils,
  AppState, GameViewEditor;

const
  HeaderH = 60;

{ TViewHome }

procedure TViewHome.Start;
begin
  inherited;
  BuildUI;
end;

procedure TViewHome.BuildUI;
begin
  { Full-window white background }
  FContent := TCastleRectangleControl.Create(FreeAtStop);
  FContent.Color := White;
  FContent.FullSize := true;
  InsertFront(FContent);

  { Header bar }
  FHeader := TCastleRectangleControl.Create(FreeAtStop);
  FHeader.Color := HexToColor('1565C0');
  FHeader.Height := HeaderH;
  FHeader.WidthFraction := 1;
  FHeader.Anchor(vpTop, vpTop);
  FHeader.Anchor(hpLeft, hpLeft);
  InsertFront(FHeader);

  FTitleLbl := TCastleLabel.Create(FreeAtStop);
  FTitleLbl.Caption := 'BTT-Writer';
  FTitleLbl.Color := White;
  FTitleLbl.FontSize := 22;
  FTitleLbl.Anchor(hpMiddle, hpMiddle);
  FTitleLbl.Anchor(vpMiddle, vpMiddle);
  FHeader.InsertFront(FTitleLbl);

  FUserLbl := TCastleLabel.Create(FreeAtStop);
  FUserLbl.Caption := 'Local User';
  FUserLbl.Color := HexToColor('BBDEFB');
  FUserLbl.FontSize := 13;
  FUserLbl.Anchor(hpRight, hpRight, -16);
  FUserLbl.Anchor(vpMiddle, vpMiddle);
  FHeader.InsertFront(FUserLbl);

  { Welcome text }
  FWelcomeLbl := TCastleLabel.Create(FreeAtStop);
  FWelcomeLbl.Caption :=
    'Welcome to BTT-Writer' + LineEnding +
    LineEnding +
    'Open a project to begin translating.';
  FWelcomeLbl.Color := HexToColor('212121');
  FWelcomeLbl.FontSize := 18;
  FWelcomeLbl.Alignment := hpMiddle;
  FWelcomeLbl.Anchor(hpMiddle, hpMiddle);
  FWelcomeLbl.Anchor(vpMiddle, vpMiddle, 60);
  InsertFront(FWelcomeLbl);

  { Open project button }
  FOpenBtn := TCastleButton.Create(FreeAtStop);
  FOpenBtn.Caption := 'Open Demo Project (Psalm 23)';
  FOpenBtn.FontSize := 16;
  FOpenBtn.OnClick := @ClickOpen;
  FOpenBtn.Anchor(hpMiddle, hpMiddle);
  FOpenBtn.Anchor(vpMiddle, vpMiddle, -20);
  InsertFront(FOpenBtn);
end;

procedure TViewHome.ClickOpen(Sender: TObject);
begin
  GAppState.Screen := asEditor;
  GAppState.EditingChunkIndex := -1;
  Container.View := ViewEditor;
end;

procedure TViewHome.Resize;
begin
  inherited;
end;

end.
