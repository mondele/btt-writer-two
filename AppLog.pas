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
  SysUtils, Classes, Zipper, DataPaths, Globals;

const
  MAX_LOG_SIZE = 2 * 1024 * 1024;  { 2 MB — rotate when exceeded }

var
  FLogFile: TextFile;
  FLogOpen: Boolean = False;
  FLogPath: string;

function FileUtil_GetFileSize(const APath: string): Int64; forward;

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

{ Archive the current log file to a timestamped .zip and start fresh }
procedure RotateLog;
var
  ArchiveName, Dir: string;
  Zip: TZipper;
begin
  if not FLogOpen then
    Exit;

  { Close current log }
  try
    WriteLn(FLogFile, '--- Log rotated ', DateTimeToStr(Now), ' ---');
    CloseFile(FLogFile);
  except
  end;
  FLogOpen := False;

  Dir := ExtractFilePath(FLogPath);
  ArchiveName := Dir + 'bttwriter2_' +
    FormatDateTime('yyyymmdd_hhnnss', Now) + '.log.zip';

  { Compress old log into archive }
  try
    Zip := TZipper.Create;
    try
      Zip.FileName := ArchiveName;
      Zip.Entries.AddFileEntry(FLogPath, 'bttwriter2.log');
      Zip.ZipAllFiles;
    finally
      Zip.Free;
    end;
  except
    { If zip fails, just delete the old log — don't block startup }
  end;

  { Start fresh }
  AssignFile(FLogFile, FLogPath);
  try
    Rewrite(FLogFile);
    FLogOpen := True;
    WriteLn(FLogFile, '--- Log opened (after rotation) ', DateTimeToStr(Now), ' ---');
    if FileExists(ArchiveName) then
      WriteLn(FLogFile, '--- Previous log archived to ', ArchiveName, ' ---');
    Flush(FLogFile);
  except
    FLogOpen := False;
  end;
end;

procedure InitLog;
var
  Dir: string;
  FileSize: Int64;
begin
  if FLogOpen then
    Exit;
  Dir := GetDataPath;
  ForceDirectories(Dir);
  FLogPath := Dir + 'bttwriter2.log';

  { Check size and rotate if needed before opening }
  if FileExists(FLogPath) then
  begin
    FileSize := FileUtil_GetFileSize(FLogPath);
    if FileSize > MAX_LOG_SIZE then
    begin
      { Open briefly just to rotate }
      AssignFile(FLogFile, FLogPath);
      try
        Append(FLogFile);
        FLogOpen := True;
        RotateLog;
        Exit; { RotateLog reopens the file }
      except
        FLogOpen := False;
      end;
    end;
  end;

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

function FileUtil_GetFileSize(const APath: string): Int64;
var
  SR: TSearchRec;
begin
  Result := 0;
  if FindFirst(APath, faAnyFile, SR) = 0 then
  begin
    Result := SR.Size;
    FindClose(SR);
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

  { GUI builds on Windows may not have stdout/stderr attached. }
  try
    WriteLn(Line);
  except
    { Ignore console write failures and continue with file logging. }
  end;

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
