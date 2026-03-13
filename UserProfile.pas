unit UserProfile;

{$mode objfpc}{$H+}

interface

type
  TUserProfile = record
    Username: string;     { server username (empty for local users) }
    FullName: string;     { display name }
    Email: string;        { server email (empty for local users) }
    Token: string;        { Gitea access token SHA (empty for local users) }
    TokenID: Integer;     { Gitea token ID on server (0 for local users) }
    IsLocal: Boolean;     { True = local profile, False = server account }
    ServerURL: string;    { base URL of the Gitea server used for login }
  end;

function LoadUserProfile: TUserProfile;
procedure SaveUserProfile(const AProfile: TUserProfile);
procedure ClearUserProfile;
function HasUserProfile: Boolean;
function IsServerUser(const AProfile: TUserProfile): Boolean;
function UserProfilePath: string;

implementation

uses
  SysUtils, Classes, fpjson, jsonparser, DataPaths, AppLog;

function UserProfilePath: string;
begin
  Result := IncludeTrailingPathDelimiter(GetDataPath) + 'user.json';
end;

function LoadUserProfile: TUserProfile;
var
  Path: string;
  SL: TStringList;
  Data: TJSONData;
  Obj: TJSONObject;
begin
  Result := Default(TUserProfile);
  Path := UserProfilePath;
  if not FileExists(Path) then
    Exit;

  SL := TStringList.Create;
  try
    SL.LoadFromFile(Path);
    Data := nil;
    try
      Data := GetJSON(SL.Text);
      if Data is TJSONObject then
      begin
        Obj := TJSONObject(Data);
        Result.Username := Obj.Get('username', '');
        Result.FullName := Obj.Get('full_name', '');
        Result.Email := Obj.Get('email', '');
        Result.Token := Obj.Get('token', '');
        Result.TokenID := Obj.Get('token_id', 0);
        Result.IsLocal := Obj.Get('is_local', False);
        Result.ServerURL := Obj.Get('server_url', '');
      end;
    except
      on E: Exception do
        LogFmt(llWarn, 'Failed to parse user profile: %s', [E.Message]);
    end;
    Data.Free;
  finally
    SL.Free;
  end;
end;

procedure SaveUserProfile(const AProfile: TUserProfile);
var
  Obj: TJSONObject;
  SL: TStringList;
  Path: string;
begin
  Path := UserProfilePath;
  ForceDirectories(ExtractFileDir(Path));
  Obj := TJSONObject.Create;
  try
    Obj.Add('username', AProfile.Username);
    Obj.Add('full_name', AProfile.FullName);
    Obj.Add('email', AProfile.Email);
    Obj.Add('token', AProfile.Token);
    Obj.Add('token_id', AProfile.TokenID);
    Obj.Add('is_local', AProfile.IsLocal);
    Obj.Add('server_url', AProfile.ServerURL);
    SL := TStringList.Create;
    try
      SL.Text := Obj.FormatJSON;
      SL.SaveToFile(Path);
      LogInfo('User profile saved');
    finally
      SL.Free;
    end;
  finally
    Obj.Free;
  end;
end;

procedure ClearUserProfile;
var
  Path: string;
begin
  Path := UserProfilePath;
  if FileExists(Path) then
    DeleteFile(Path);
  LogInfo('User profile cleared');
end;

function HasUserProfile: Boolean;
var
  P: TUserProfile;
begin
  P := LoadUserProfile;
  Result := (P.FullName <> '') or (P.Username <> '');
end;

function IsServerUser(const AProfile: TUserProfile): Boolean;
begin
  Result := (not AProfile.IsLocal) and (AProfile.Token <> '');
end;

end.
