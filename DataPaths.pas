unit DataPaths;

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

function GetDataPath: string;
function GetLibraryPath: string;
function GetTargetTranslationsPath: string;
function GetIndexPath: string;

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

end.
