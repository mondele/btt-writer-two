unit AppLog;

{$mode objfpc}{$H+}

interface

type
  TLogLevel = (llDebug, llInfo, llWarn, llError);

procedure InitLog;
procedure FinalizeLog;
procedure Log(ALevel: TLogLevel; const AMsg: string);
procedure LogDebug(const AMsg: string);
procedure LogInfo(const AMsg: string);
procedure LogWarn(const AMsg: string);
procedure LogError(const AMsg: string);
procedure LogFmt(ALevel: TLogLevel; const AFmt: string; const AArgs: array of const);
function GetLogPath: string;

implementation

uses
  SysUtils, Classes, DataPaths, Globals;

var
  FLogFile: TextFile;
  FLogOpen: Boolean = False;
  FLogPath: string;

function LevelStr(ALevel: TLogLevel): string;
begin
  case ALevel of
    llDebug: Result := 'DEBUG';
    llInfo:  Result := 'INFO';
    llWarn:  Result := 'WARN';
    llError: Result := 'ERROR';
  else
    Result := '?';
  end;
end;

procedure InitLog;
var
  Dir: string;
begin
  if FLogOpen then
    Exit;
  Dir := GetDataPath;
  ForceDirectories(Dir);
  FLogPath := Dir + 'bttwriter2.log';

  AssignFile(FLogFile, FLogPath);
  try
    if FileExists(FLogPath) then
      Append(FLogFile)
    else
      Rewrite(FLogFile);
    FLogOpen := True;
    WriteLn(FLogFile, '--- Log opened ', DateTimeToStr(Now), ' ---');
    Flush(FLogFile);
  except
    FLogOpen := False;
  end;
end;

procedure FinalizeLog;
begin
  if FLogOpen then
  begin
    WriteLn(FLogFile, '--- Log closed ', DateTimeToStr(Now), ' ---');
    CloseFile(FLogFile);
    FLogOpen := False;
  end;
end;

procedure Log(ALevel: TLogLevel; const AMsg: string);
var
  Line: string;
begin
  { Debug-level messages only emitted when Verbose flag is set }
  if (ALevel = llDebug) and (not Verbose) then
    Exit;

  Line := FormatDateTime('hh:nn:ss.zzz', Now) + ' [' + LevelStr(ALevel) + '] ' + AMsg;

  { Always write to stdout for console runs }
  WriteLn(Line);

  { Write to log file if open }
  if FLogOpen then
  begin
    try
      WriteLn(FLogFile, Line);
      Flush(FLogFile);
    except
      { Ignore write errors — don't crash the app for logging }
    end;
  end;
end;

procedure LogDebug(const AMsg: string);
begin
  Log(llDebug, AMsg);
end;

procedure LogInfo(const AMsg: string);
begin
  Log(llInfo, AMsg);
end;

procedure LogWarn(const AMsg: string);
begin
  Log(llWarn, AMsg);
end;

procedure LogError(const AMsg: string);
begin
  Log(llError, AMsg);
end;

procedure LogFmt(ALevel: TLogLevel; const AFmt: string; const AArgs: array of const);
begin
  Log(ALevel, Format(AFmt, AArgs));
end;

function GetLogPath: string;
begin
  Result := FLogPath;
end;

finalization
  FinalizeLog;

end.
