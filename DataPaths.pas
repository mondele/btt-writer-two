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

function GetDataPath: string;
begin
  {$IFDEF LINUX}
  Result := IncludeTrailingPathDelimiter(GetEnvironmentVariable('HOME'))
            + '.config' + DirectorySeparator + 'BTT-Writer' + DirectorySeparator;
  {$ENDIF}
  {$IFDEF DARWIN}
  Result := IncludeTrailingPathDelimiter(GetEnvironmentVariable('HOME'))
            + 'Library' + DirectorySeparator + 'Application Support'
            + DirectorySeparator + 'BTT-Writer' + DirectorySeparator;
  {$ENDIF}
  {$IFDEF WINDOWS}
  Result := IncludeTrailingPathDelimiter(GetEnvironmentVariable('LOCALAPPDATA'))
            + 'BTT-Writer' + DirectorySeparator;
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
  Result := IncludeTrailingPathDelimiter(DEFAULT_APP_INSTALL_ROOT) +
    'resources' + DirectorySeparator + 'app' + DirectorySeparator +
    'resource_containers.zip';
end;

end.
