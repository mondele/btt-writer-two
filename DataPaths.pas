unit DataPaths;

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

function GetDataPath: string;
function GetLibraryPath: string;
function GetTargetTranslationsPath: string;
function GetIndexPath: string;
function GetBundledResourceContainersZipPath: string;

implementation

function GetExecutableBasePath: string;
begin
  Result := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0)));
end;

function GetFirstNonEmptyEnv(const Names: array of string): string;
var
  I: Integer;
begin
  Result := '';
  for I := Low(Names) to High(Names) do
  begin
    Result := Trim(GetEnvironmentVariable(Names[I]));
    if Result <> '' then
      Exit;
  end;
end;

function GetDataPath: string;
var
  BasePath: string;
begin
  {$IFDEF LINUX}
  BasePath := Trim(GetEnvironmentVariable('HOME'));
  if BasePath = '' then
    BasePath := GetExecutableBasePath;
  Result := IncludeTrailingPathDelimiter(BasePath) + '.config' +
    DirectorySeparator + 'BTT-Writer' + DirectorySeparator;
  {$ENDIF}
  {$IFDEF DARWIN}
  BasePath := Trim(GetEnvironmentVariable('HOME'));
  if BasePath = '' then
    BasePath := GetExecutableBasePath;
  Result := IncludeTrailingPathDelimiter(BasePath) + 'Library' +
    DirectorySeparator + 'Application Support' + DirectorySeparator +
    'BTT-Writer' + DirectorySeparator;
  {$ENDIF}
  {$IFDEF WINDOWS}
  BasePath := GetFirstNonEmptyEnv(['LOCALAPPDATA', 'APPDATA']);
  if (BasePath = '') and (Trim(GetEnvironmentVariable('USERPROFILE')) <> '') then
    BasePath := IncludeTrailingPathDelimiter(Trim(GetEnvironmentVariable('USERPROFILE'))) +
      'AppData' + DirectorySeparator + 'Local';
  if BasePath = '' then
    BasePath := GetExecutableBasePath;
  Result := IncludeTrailingPathDelimiter(BasePath) + 'BTT-Writer' +
    DirectorySeparator;
  {$ENDIF}
end;

function GetLibraryPath: string;
begin
  Result := GetDataPath + 'library' + DirectorySeparator
            + 'resource_containers' + DirectorySeparator;
end;

function GetTargetTranslationsPath: string;
begin
  Result := GetDataPath + 'targetTranslations' + DirectorySeparator;
end;

function GetIndexPath: string;
begin
  Result := GetDataPath + 'index' + DirectorySeparator
            + 'resource_containers' + DirectorySeparator;
end;

function GetBundledResourceContainersZipPath: string;
const
  {$IFDEF LINUX}
  DEFAULT_APP_INSTALL_ROOT = '/opt/BTT-Writer';
  {$ENDIF}
  {$IFDEF DARWIN}
  DEFAULT_APP_INSTALL_ROOT = '/Applications/BTT-Writer.app/Contents';
  {$ENDIF}
  {$IFDEF WINDOWS}
  DEFAULT_APP_INSTALL_ROOT = 'C:\Program Files\BTT-Writer';
  {$ENDIF}
begin
  Result := GetExecutableBasePath + 'resources' + DirectorySeparator + 'app' +
    DirectorySeparator + 'resource_containers.zip';
  if FileExists(Result) then
    Exit;

  Result := IncludeTrailingPathDelimiter(DEFAULT_APP_INSTALL_ROOT) + 'resources' +
    DirectorySeparator + 'app' + DirectorySeparator + 'resource_containers.zip';
end;

end.
