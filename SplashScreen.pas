unit SplashScreen;

{$mode objfpc}{$H+}

interface

procedure ShowStartupSplash;
procedure UpdateStartupSplash(const StatusText: string);
procedure HideStartupSplash;

implementation

uses
  Classes, SysUtils, Forms, Controls, Graphics, ExtCtrls, StdCtrls,
  Globals;

resourcestring
  rsVersionPrefix = 'Version ';

var
  SplashForm: TForm = nil;
  StatusPanel: TPanel = nil;
  StatusLabel: TLabel = nil;

procedure ShowStartupSplash;
var
  TopPanel: TPanel;
  LogoPanel: TPanel;
  LogoGlyph: TLabel;
  TitleLabel: TLabel;
  VersionLabel: TLabel;
begin
  if SplashForm <> nil then
    Exit;

  SplashForm := TForm.Create(nil);
  SplashForm.BorderStyle := bsNone;
  SplashForm.BorderIcons := [];
  SplashForm.Position := poScreenCenter;
  SplashForm.Font.Name := 'Noto Sans';
  SplashForm.Color := $00EDEDED;
  SplashForm.ClientWidth := 420;
  SplashForm.ClientHeight := 170;

  TopPanel := TPanel.Create(SplashForm);
  TopPanel.Parent := SplashForm;
  TopPanel.Align := alClient;
  TopPanel.BevelOuter := bvNone;
  TopPanel.Color := clWhite;

  LogoPanel := TPanel.Create(TopPanel);
  LogoPanel.Parent := TopPanel;
  LogoPanel.SetBounds(24, 36, 84, 84);
  LogoPanel.BevelOuter := bvNone;
  LogoPanel.Color := $00F2F7FF;

  LogoGlyph := TLabel.Create(LogoPanel);
  LogoGlyph.Parent := LogoPanel;
  LogoGlyph.AutoSize := False;
  LogoGlyph.SetBounds(0, 0, LogoPanel.Width, LogoPanel.Height);
  LogoGlyph.Alignment := taLeftJustify;
  LogoGlyph.Layout := tlCenter;
  LogoGlyph.Font.Height := -28;
  LogoGlyph.Font.Style := [fsBold];
  LogoGlyph.Font.Name := 'Noto Sans';
  LogoGlyph.Font.Color := $00AA6A00;
  LogoGlyph.Caption := 'B';

  TitleLabel := TLabel.Create(TopPanel);
  TitleLabel.Parent := TopPanel;
  TitleLabel.Left := 140;
  TitleLabel.Top := 42;
  TitleLabel.Font.Height := -48 div 2;
  TitleLabel.Font.Name := 'Noto Sans';
  TitleLabel.Font.Color := $00202020;
  TitleLabel.Caption := APP_NAME;

  VersionLabel := TLabel.Create(TopPanel);
  VersionLabel.Parent := TopPanel;
  VersionLabel.Left := 140;
  VersionLabel.Top := 78;
  VersionLabel.Font.Height := -24 div 2;
  VersionLabel.Font.Name := 'Noto Sans';
  VersionLabel.Font.Color := $00444444;
  VersionLabel.Caption := rsVersionPrefix + APP_VERSION;

  StatusPanel := TPanel.Create(SplashForm);
  StatusPanel.Parent := SplashForm;
  StatusPanel.Align := alBottom;
  StatusPanel.Height := 28;
  StatusPanel.BevelOuter := bvNone;
  StatusPanel.Color := $00CC6300;

  StatusLabel := TLabel.Create(StatusPanel);
  StatusLabel.Parent := StatusPanel;
  StatusLabel.Left := 16;
  StatusLabel.Top := 6;
  StatusLabel.Font.Height := -14;
  StatusLabel.Font.Name := 'Noto Sans';
  StatusLabel.Font.Color := clWhite;
  StatusLabel.Caption := '';

  SplashForm.Show;
  SplashForm.Update;
  Application.ProcessMessages;
end;

procedure UpdateStartupSplash(const StatusText: string);
begin
  if SplashForm = nil then
    ShowStartupSplash;
  if StatusLabel <> nil then
    StatusLabel.Caption := StatusText;
  if SplashForm <> nil then
  begin
    SplashForm.Update;
    Application.ProcessMessages;
  end;
end;

procedure HideStartupSplash;
begin
  if SplashForm <> nil then
  begin
    SplashForm.Hide;
    FreeAndNil(SplashForm);
    StatusPanel := nil;
    StatusLabel := nil;
    Application.ProcessMessages;
  end;
end;

end.
