unit GiteaClient;

{$mode objfpc}{$H+}

interface

resourcestring
  rsGiteaConnectionError = 'Could not connect to the server. Check your internet connection.';
  rsGiteaBadCredentials = 'Invalid username or password.';
  rsGiteaUserNotFound = 'User not found on the server.';
  rsGiteaTokenCreateFailed = 'Failed to create access token.';
  rsGiteaUnexpectedError = 'Server error: ';

type
  TGiteaTokenInfo = record
    ID: Integer;
    Name: string;
    SHA1: string;  { the actual token value — only returned on creation }
  end;

  TGiteaUserInfo = record
    ID: Integer;
    Username: string;
    FullName: string;
    Email: string;
  end;

  TGiteaTokenArray = array of TGiteaTokenInfo;

{ Validate credentials and return user info.
  Raises exception on failure with a user-friendly message. }
function GiteaGetUser(const AServerURL, AUsername, APassword: string): TGiteaUserInfo;

{ List all access tokens for the user.
  Requires username + password (token auth cannot list tokens). }
function GiteaListTokens(const AServerURL, AUsername, APassword: string): TGiteaTokenArray;

{ Create a new access token. Returns the token with SHA1 populated. }
function GiteaCreateToken(const AServerURL, AUsername, APassword, ATokenName: string): TGiteaTokenInfo;

{ Delete an access token by ID. }
procedure GiteaDeleteToken(const AServerURL, AUsername, APassword: string; ATokenID: Integer);

{ Build the standard token name for this machine. }
function BuildTokenName: string;

{ Full login flow: validate credentials, clean up old token if exists,
  create new token. Returns user info + token. }
procedure GiteaLogin(const AServerURL, AUsername, APassword: string;
  out UserInfo: TGiteaUserInfo; out Token: TGiteaTokenInfo);

{ Delete token from server during logout. Errors are logged but not raised. }
procedure GiteaLogout(const AServerURL, AUsername, AToken: string; ATokenID: Integer);

{ Get the default data server URL. }
function DefaultDataServerURL: string;

{ Get the account creation URL for the given server. }
function AccountCreationURL(const AServerURL: string): string;

{ --- Repo API --- }
type
  TGiteaRepoInfo = record
    ID: Integer;
    Name: string;
    FullName: string;   { owner/name }
    CloneURL: string;   { HTTPS clone URL }
    Owner: string;
    Description: string;
  end;
  TGiteaRepoArray = array of TGiteaRepoInfo;

function GiteaCreateRepo(const AServerURL, AToken, ARepoName: string;
  out CloneURL: string; out ErrorMsg: string): Boolean;
function GiteaRepoExists(const AServerURL, AToken, AOwner, ARepoName: string): Boolean;
function GiteaSearchRepos(const AServerURL, AToken, AQuery: string;
  ALimit: Integer; out Repos: TGiteaRepoArray; out ErrorMsg: string): Boolean;
function GiteaListUserRepos(const AServerURL, AToken, AUsername: string;
  ALimit: Integer; out Repos: TGiteaRepoArray; out ErrorMsg: string): Boolean;

implementation

uses
  SysUtils, Classes, fpjson, jsonparser, fphttpclient, opensslsockets,
  base64, AppLog, AppSettings;

const
  DEFAULT_SERVER = 'https://content.bibletranslationtools.org';

function DefaultDataServerURL: string;
begin
  Result := GetEffectiveDataServer;
  if Result = '' then
    Result := DEFAULT_SERVER;
end;

function AccountCreationURL(const AServerURL: string): string;
begin
  Result := AServerURL + '/user/sign_up';
end;

function BasicAuthHeader(const AUsername, APassword: string): string;
begin
  Result := 'Basic ' + EncodeStringBase64(AUsername + ':' + APassword);
end;

function BuildTokenName: string;
begin
  {$IFDEF LINUX}
  Result := 'btt-writer2_' + GetEnvironmentVariable('HOSTNAME') + '_linux';
  {$ENDIF}
  {$IFDEF DARWIN}
  Result := 'btt-writer2_' + GetEnvironmentVariable('HOSTNAME') + '_macos';
  {$ENDIF}
  {$IFDEF WINDOWS}
  Result := 'btt-writer2_' + GetEnvironmentVariable('COMPUTERNAME') + '_windows';
  {$ENDIF}
  if Result = 'btt-writer2__' then
    Result := 'btt-writer2_unknown';
end;

function DoGet(const AURL, AUsername, APassword: string): string;
var
  Http: TFPHTTPClient;
begin
  Http := TFPHTTPClient.Create(nil);
  try
    Http.AddHeader('Authorization', BasicAuthHeader(AUsername, APassword));
    Http.AddHeader('Accept', 'application/json');
    Http.AllowRedirect := True;
    Http.ConnectTimeout := 10000;
    Http.IOTimeout := 15000;
    try
      Result := Http.Get(AURL);
    except
      on E: EHTTPClient do
      begin
        LogFmt(llError, 'HTTP GET %s failed: %d %s', [AURL, Http.ResponseStatusCode, E.Message]);
        case Http.ResponseStatusCode of
          401: raise Exception.Create(rsGiteaBadCredentials);
          404: raise Exception.Create(rsGiteaUserNotFound);
        else
          raise Exception.Create(rsGiteaUnexpectedError + E.Message);
        end;
      end;
      on E: Exception do
      begin
        LogFmt(llError, 'HTTP GET %s error: %s', [AURL, E.Message]);
        raise Exception.Create(rsGiteaConnectionError);
      end;
    end;
    { Check status code for non-exception failures }
    if (Http.ResponseStatusCode >= 400) then
    begin
      LogFmt(llError, 'HTTP GET %s status: %d body: %s', [AURL, Http.ResponseStatusCode, Result]);
      case Http.ResponseStatusCode of
        401: raise Exception.Create(rsGiteaBadCredentials);
        404: raise Exception.Create(rsGiteaUserNotFound);
      else
        raise Exception.Create(rsGiteaUnexpectedError + IntToStr(Http.ResponseStatusCode));
      end;
    end;
  finally
    Http.Free;
  end;
end;

function DoPost(const AURL, AUsername, APassword, ABody: string): string;
var
  Http: TFPHTTPClient;
  ReqStream: TStringStream;
begin
  Http := TFPHTTPClient.Create(nil);
  ReqStream := TStringStream.Create(ABody);
  try
    Http.AddHeader('Authorization', BasicAuthHeader(AUsername, APassword));
    Http.AddHeader('Content-Type', 'application/json');
    Http.AddHeader('Accept', 'application/json');
    Http.AllowRedirect := True;
    Http.ConnectTimeout := 10000;
    Http.IOTimeout := 15000;
    Http.RequestBody := ReqStream;
    try
      Result := Http.Post(AURL);
    except
      on E: EHTTPClient do
      begin
        LogFmt(llError, 'HTTP POST %s failed: %d %s', [AURL, Http.ResponseStatusCode, E.Message]);
        raise Exception.Create(rsGiteaUnexpectedError + E.Message);
      end;
      on E: Exception do
      begin
        LogFmt(llError, 'HTTP POST %s error: %s', [AURL, E.Message]);
        raise Exception.Create(rsGiteaConnectionError);
      end;
    end;
    if Http.ResponseStatusCode >= 400 then
    begin
      LogFmt(llError, 'HTTP POST %s status: %d body: %s', [AURL, Http.ResponseStatusCode, Result]);
      raise Exception.Create(rsGiteaUnexpectedError + IntToStr(Http.ResponseStatusCode));
    end;
  finally
    ReqStream.Free;
    Http.Free;
  end;
end;

procedure DoDelete(const AURL, AUsername, APassword: string);
var
  Http: TFPHTTPClient;
begin
  Http := TFPHTTPClient.Create(nil);
  try
    Http.AddHeader('Authorization', BasicAuthHeader(AUsername, APassword));
    Http.AllowRedirect := True;
    Http.ConnectTimeout := 10000;
    Http.IOTimeout := 15000;
    try
      Http.Delete(AURL);
    except
      on E: Exception do
        LogFmt(llWarn, 'HTTP DELETE %s error: %s', [AURL, E.Message]);
    end;
  finally
    Http.Free;
  end;
end;

function GiteaGetUser(const AServerURL, AUsername, APassword: string): TGiteaUserInfo;
var
  Body: string;
  Data: TJSONData;
  Obj: TJSONObject;
begin
  Result := Default(TGiteaUserInfo);
  Body := DoGet(AServerURL + '/api/v1/user', AUsername, APassword);
  Data := GetJSON(Body);
  try
    if Data is TJSONObject then
    begin
      Obj := TJSONObject(Data);
      Result.ID := Obj.Get('id', 0);
      Result.Username := Obj.Get('login', AUsername);
      Result.FullName := Obj.Get('full_name', '');
      Result.Email := Obj.Get('email', '');
    end;
  finally
    Data.Free;
  end;
  LogFmt(llInfo, 'GiteaGetUser: id=%d username=%s', [Result.ID, Result.Username]);
end;

function GiteaListTokens(const AServerURL, AUsername, APassword: string): TGiteaTokenArray;
var
  Body: string;
  Data: TJSONData;
  Arr: TJSONArray;
  Obj: TJSONObject;
  I: Integer;
begin
  SetLength(Result, 0);
  Body := DoGet(AServerURL + '/api/v1/users/' + AUsername + '/tokens', AUsername, APassword);
  Data := GetJSON(Body);
  try
    if Data is TJSONArray then
    begin
      Arr := TJSONArray(Data);
      SetLength(Result, Arr.Count);
      for I := 0 to Arr.Count - 1 do
      begin
        Obj := Arr.Objects[I];
        Result[I].ID := Obj.Get('id', 0);
        Result[I].Name := Obj.Get('name', '');
        Result[I].SHA1 := '';  { Not returned in list }
      end;
    end;
  finally
    Data.Free;
  end;
  LogFmt(llInfo, 'GiteaListTokens: found %d tokens', [Length(Result)]);
end;

function GiteaCreateToken(const AServerURL, AUsername, APassword, ATokenName: string): TGiteaTokenInfo;
var
  ReqObj: TJSONObject;
  Scopes: TJSONArray;
  Body, Resp: string;
  Data: TJSONData;
  Obj: TJSONObject;
begin
  Result := Default(TGiteaTokenInfo);
  ReqObj := TJSONObject.Create;
  try
    ReqObj.Add('name', ATokenName);
    Scopes := TJSONArray.Create;
    Scopes.Add('write:user');
    Scopes.Add('write:repository');
    ReqObj.Add('scopes', Scopes);
    Body := ReqObj.AsJSON;
  finally
    ReqObj.Free;
  end;

  Resp := DoPost(AServerURL + '/api/v1/users/' + AUsername + '/tokens', AUsername, APassword, Body);
  Data := GetJSON(Resp);
  try
    if Data is TJSONObject then
    begin
      Obj := TJSONObject(Data);
      Result.ID := Obj.Get('id', 0);
      Result.Name := Obj.Get('name', '');
      Result.SHA1 := Obj.Get('sha1', '');
    end;
  finally
    Data.Free;
  end;

  if Result.SHA1 = '' then
    raise Exception.Create(rsGiteaTokenCreateFailed);

  LogFmt(llInfo, 'GiteaCreateToken: id=%d name=%s', [Result.ID, Result.Name]);
end;

procedure GiteaDeleteToken(const AServerURL, AUsername, APassword: string; ATokenID: Integer);
begin
  DoDelete(AServerURL + '/api/v1/users/' + AUsername + '/tokens/' + IntToStr(ATokenID),
    AUsername, APassword);
  LogFmt(llInfo, 'GiteaDeleteToken: id=%d', [ATokenID]);
end;

procedure GiteaLogin(const AServerURL, AUsername, APassword: string;
  out UserInfo: TGiteaUserInfo; out Token: TGiteaTokenInfo);
var
  Tokens: TGiteaTokenArray;
  TokenName: string;
  I: Integer;
begin
  { Step 1: Validate credentials }
  UserInfo := GiteaGetUser(AServerURL, AUsername, APassword);

  { Step 2: List existing tokens and delete our old one if present }
  TokenName := BuildTokenName;
  Tokens := GiteaListTokens(AServerURL, AUsername, APassword);
  for I := 0 to Length(Tokens) - 1 do
  begin
    if Tokens[I].Name = TokenName then
    begin
      LogFmt(llInfo, 'Deleting old token: id=%d name=%s', [Tokens[I].ID, Tokens[I].Name]);
      GiteaDeleteToken(AServerURL, AUsername, APassword, Tokens[I].ID);
    end;
  end;

  { Step 3: Create new token }
  Token := GiteaCreateToken(AServerURL, AUsername, APassword, TokenName);
end;

procedure GiteaLogout(const AServerURL, AUsername, AToken: string; ATokenID: Integer);
var
  Http: TFPHTTPClient;
begin
  if (AServerURL = '') or (AToken = '') or (ATokenID = 0) then
    Exit;
  LogFmt(llInfo, 'GiteaLogout: user=%s tokenId=%d', [AUsername, ATokenID]);
  Http := TFPHTTPClient.Create(nil);
  try
    Http.AddHeader('Authorization', 'token ' + AToken);
    Http.AllowRedirect := True;
    Http.ConnectTimeout := 10000;
    Http.IOTimeout := 15000;
    try
      Http.Delete(AServerURL + '/api/v1/users/' + AUsername + '/tokens/' + IntToStr(ATokenID));
      LogFmt(llInfo, 'GiteaLogout: deleted token %d from server', [ATokenID]);
    except
      on E: Exception do
        LogFmt(llWarn, 'GiteaLogout: failed to delete token: %s', [E.Message]);
    end;
  finally
    Http.Free;
  end;
end;

{ --- Token-based HTTP helpers for repo API --- }

function DoTokenGet(const AURL, AToken: string): string;
var
  Http: TFPHTTPClient;
begin
  Http := TFPHTTPClient.Create(nil);
  try
    Http.AddHeader('Authorization', 'token ' + AToken);
    Http.AddHeader('Accept', 'application/json');
    Http.AllowRedirect := True;
    Http.ConnectTimeout := 10000;
    Http.IOTimeout := 15000;
    try
      Result := Http.Get(AURL);
    except
      on E: Exception do
      begin
        LogFmt(llError, 'HTTP GET %s error: %s', [AURL, E.Message]);
        raise Exception.Create(rsGiteaConnectionError);
      end;
    end;
    if Http.ResponseStatusCode >= 400 then
    begin
      LogFmt(llError, 'HTTP GET %s status: %d', [AURL, Http.ResponseStatusCode]);
      raise Exception.Create(rsGiteaUnexpectedError + IntToStr(Http.ResponseStatusCode));
    end;
  finally
    Http.Free;
  end;
end;

function DoTokenPost(const AURL, AToken, ABody: string): string;
var
  Http: TFPHTTPClient;
  ReqStream: TStringStream;
begin
  Http := TFPHTTPClient.Create(nil);
  ReqStream := TStringStream.Create(ABody);
  try
    Http.AddHeader('Authorization', 'token ' + AToken);
    Http.AddHeader('Content-Type', 'application/json');
    Http.AddHeader('Accept', 'application/json');
    Http.AllowRedirect := True;
    Http.ConnectTimeout := 10000;
    Http.IOTimeout := 15000;
    Http.RequestBody := ReqStream;
    try
      Result := Http.Post(AURL);
    except
      on E: Exception do
      begin
        LogFmt(llError, 'HTTP POST %s error: %s', [AURL, E.Message]);
        raise Exception.Create(rsGiteaConnectionError);
      end;
    end;
    if Http.ResponseStatusCode >= 400 then
    begin
      LogFmt(llError, 'HTTP POST %s status: %d body: %s', [AURL, Http.ResponseStatusCode, Result]);
      raise Exception.Create(rsGiteaUnexpectedError + IntToStr(Http.ResponseStatusCode));
    end;
  finally
    ReqStream.Free;
    Http.Free;
  end;
end;

function ParseRepoInfo(Obj: TJSONObject): TGiteaRepoInfo;
var
  OwnerObj: TJSONObject;
begin
  Result := Default(TGiteaRepoInfo);
  Result.ID := Obj.Get('id', 0);
  Result.Name := Obj.Get('name', '');
  Result.FullName := Obj.Get('full_name', '');
  Result.CloneURL := Obj.Get('clone_url', '');
  Result.Description := Obj.Get('description', '');
  if Obj.Find('owner') is TJSONObject then
  begin
    OwnerObj := TJSONObject(Obj.Find('owner'));
    Result.Owner := OwnerObj.Get('login', '');
  end;
end;

function GiteaCreateRepo(const AServerURL, AToken, ARepoName: string;
  out CloneURL: string; out ErrorMsg: string): Boolean;
var
  ReqObj: TJSONObject;
  Body, Resp: string;
  Data: TJSONData;
  Obj: TJSONObject;
begin
  Result := False;
  CloneURL := '';
  ErrorMsg := '';

  ReqObj := TJSONObject.Create;
  try
    ReqObj.Add('name', ARepoName);
    ReqObj.Add('auto_init', False);
    ReqObj.Add('private', False);
    Body := ReqObj.AsJSON;
  finally
    ReqObj.Free;
  end;

  try
    Resp := DoTokenPost(AServerURL + '/api/v1/user/repos', AToken, Body);
  except
    on E: Exception do
    begin
      ErrorMsg := E.Message;
      Exit;
    end;
  end;

  Data := GetJSON(Resp);
  try
    if Data is TJSONObject then
    begin
      Obj := TJSONObject(Data);
      CloneURL := Obj.Get('clone_url', '');
      Result := CloneURL <> '';
      if not Result then
        ErrorMsg := 'Server did not return a clone URL.';
    end
    else
      ErrorMsg := 'Unexpected server response.';
  finally
    Data.Free;
  end;

  LogFmt(llInfo, 'GiteaCreateRepo: name=%s clone_url=%s', [ARepoName, CloneURL]);
end;

function GiteaRepoExists(const AServerURL, AToken, AOwner, ARepoName: string): Boolean;
var
  Http: TFPHTTPClient;
begin
  Result := False;
  Http := TFPHTTPClient.Create(nil);
  try
    Http.AddHeader('Authorization', 'token ' + AToken);
    Http.AddHeader('Accept', 'application/json');
    Http.AllowRedirect := True;
    Http.ConnectTimeout := 10000;
    Http.IOTimeout := 15000;
    try
      Http.Get(AServerURL + '/api/v1/repos/' + AOwner + '/' + ARepoName);
      Result := (Http.ResponseStatusCode >= 200) and (Http.ResponseStatusCode < 300);
    except
      Result := False;
    end;
  finally
    Http.Free;
  end;
  LogFmt(llInfo, 'GiteaRepoExists: %s/%s = %s', [AOwner, ARepoName, BoolToStr(Result, 'yes', 'no')]);
end;

function GiteaSearchRepos(const AServerURL, AToken, AQuery: string;
  ALimit: Integer; out Repos: TGiteaRepoArray; out ErrorMsg: string): Boolean;
var
  Resp: string;
  Data: TJSONData;
  Obj: TJSONObject;
  Arr: TJSONArray;
  Node: TJSONData;
  I: Integer;
begin
  Result := False;
  SetLength(Repos, 0);
  ErrorMsg := '';

  if ALimit <= 0 then
    ALimit := 50;

  try
    Resp := DoTokenGet(AServerURL + '/api/v1/repos/search?q=' + AQuery +
      '&limit=' + IntToStr(ALimit), AToken);
  except
    on E: Exception do
    begin
      ErrorMsg := E.Message;
      Exit;
    end;
  end;

  Data := GetJSON(Resp);
  try
    if Data is TJSONObject then
    begin
      Obj := TJSONObject(Data);
      Node := Obj.Find('data');
      if Node is TJSONArray then
        Arr := TJSONArray(Node)
      else
        Exit;
    end
    else if Data is TJSONArray then
      Arr := TJSONArray(Data)
    else
      Exit;

    SetLength(Repos, Arr.Count);
    for I := 0 to Arr.Count - 1 do
    begin
      if Arr.Items[I] is TJSONObject then
        Repos[I] := ParseRepoInfo(TJSONObject(Arr.Items[I]));
    end;
    Result := True;
  finally
    Data.Free;
  end;

  LogFmt(llInfo, 'GiteaSearchRepos: query=%s found=%d', [AQuery, Length(Repos)]);
end;

function GiteaListUserRepos(const AServerURL, AToken, AUsername: string;
  ALimit: Integer; out Repos: TGiteaRepoArray; out ErrorMsg: string): Boolean;
var
  Resp: string;
  Data: TJSONData;
  Arr: TJSONArray;
  I, Page: Integer;
  PageRepos: TGiteaRepoArray;
  Batch: TJSONArray;
begin
  Result := False;
  SetLength(Repos, 0);
  ErrorMsg := '';
  if ALimit <= 0 then
    ALimit := 50;

  Page := 1;
  repeat
    try
      Resp := DoTokenGet(AServerURL + '/api/v1/users/' + AUsername +
        '/repos?limit=' + IntToStr(ALimit) + '&page=' + IntToStr(Page), AToken);
    except
      on E: Exception do
      begin
        ErrorMsg := E.Message;
        Exit;
      end;
    end;

    Data := GetJSON(Resp);
    try
      if Data is TJSONArray then
        Batch := TJSONArray(Data)
      else
        Break;
      if Batch.Count = 0 then
        Break;
      SetLength(PageRepos, Batch.Count);
      for I := 0 to Batch.Count - 1 do
      begin
        if Batch.Items[I] is TJSONObject then
          PageRepos[I] := ParseRepoInfo(TJSONObject(Batch.Items[I]));
      end;
      SetLength(Repos, Length(Repos) + Length(PageRepos));
      for I := 0 to Length(PageRepos) - 1 do
        Repos[Length(Repos) - Length(PageRepos) + I] := PageRepos[I];
      if Batch.Count < ALimit then
        Break;
    finally
      Data.Free;
    end;
    Inc(Page);
  until False;

  Result := True;
  LogFmt(llInfo, 'GiteaListUserRepos: user=%s found=%d', [AUsername, Length(Repos)]);
end;

end.
