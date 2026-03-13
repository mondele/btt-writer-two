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

procedure AssignSplashIcon(ATarget: TPicture);
var
  AppIcon: TIcon;
begin
  if ATarget = nil then
    Exit;

  if not Application.Icon.Empty then
  begin
    ATarget.Icon.Assign(Application.Icon);
    Exit;
  end;

  AppIcon := TIcon.Create;
  try
    try
      AppIcon.LoadFromResourceName(HInstance, 'MAINICON');
      if not AppIcon.Empty then
        ATarget.Icon.Assign(AppIcon);
    except
      { Leave the splash icon empty if the resource cannot be loaded. }
    end;
  finally
    AppIcon.Free;
  end;
end;

procedure ShowStartupSplash;
var
  TopPanel: TPanel;
  LogoImage: TImage;
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

  { App icon from application resource }
  LogoImage := TImage.Create(TopPanel);
  LogoImage.Parent := TopPanel;
  LogoImage.SetBounds(24, 36, 84, 84);
  LogoImage.Stretch := True;
  LogoImage.Proportional := True;
  LogoImage.Center := True;
  AssignSplashIcon(LogoImage.Picture);

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
