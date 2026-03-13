unit GitUtils;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes;

function RunCommandCapture(const Exe: string; const Args: array of string;
  const WorkDir: string; out OutputText, ErrorText: string;
  out ExitCode: Integer): Boolean;
function EnsureProjectCommitted(const ProjectDir: string; out ErrorMsg: string): Boolean;
function ShellQuote(const S: string): string;

implementation

uses
  Process;

function ShellQuote(const S: string): string;
begin
  Result := '''' + StringReplace(S, '''', '''"''"''', [rfReplaceAll]) + '''';
end;

function RunCommandCapture(const Exe: string; const Args: array of string;
  const WorkDir: string; out OutputText, ErrorText: string;
  out ExitCode: Integer): Boolean;
var
  P: TProcess;
  OutS, ErrS: TStringStream;
  I: Integer;
  Buf: array[0..4095] of Byte;
  N: LongInt;
begin
  Result := False;
  OutputText := '';
  ErrorText := '';
  ExitCode := -1;

  P := TProcess.Create(nil);
  OutS := TStringStream.Create('');
  ErrS := TStringStream.Create('');
  try
    P.Executable := Exe;
    if WorkDir <> '' then
      P.CurrentDirectory := WorkDir;
    P.Options := [poUsePipes];
    for I := 0 to High(Args) do
      P.Parameters.Add(Args[I]);
    try
      P.Execute;
    except
      on E: Exception do
      begin
        ErrorText := E.Message;
        Exit(False);
      end;
    end;

    while P.Running do
    begin
      while P.Output.NumBytesAvailable > 0 do
      begin
        N := P.Output.Read(Buf, SizeOf(Buf));
        if N > 0 then
          OutS.WriteBuffer(Buf, N);
      end;
      while P.Stderr.NumBytesAvailable > 0 do
      begin
        N := P.Stderr.Read(Buf, SizeOf(Buf));
        if N > 0 then
          ErrS.WriteBuffer(Buf, N);
      end;
      Sleep(5);
    end;
    while P.Output.NumBytesAvailable > 0 do
    begin
      N := P.Output.Read(Buf, SizeOf(Buf));
      if N > 0 then
        OutS.WriteBuffer(Buf, N);
    end;
    while P.Stderr.NumBytesAvailable > 0 do
    begin
      N := P.Stderr.Read(Buf, SizeOf(Buf));
      if N > 0 then
        ErrS.WriteBuffer(Buf, N);
    end;

    OutputText := OutS.DataString;
    ErrorText := ErrS.DataString;
    ExitCode := P.ExitStatus;
    Result := True;
  finally
    ErrS.Free;
    OutS.Free;
    P.Free;
  end;
end;

function EnsureProjectCommitted(const ProjectDir: string; out ErrorMsg: string): Boolean;
var
  OutText, ErrText: string;
  ExitCode: Integer;
begin
  Result := False;
  ErrorMsg := '';

  { If this is not a git repo, skip commit enforcement. }
  if not RunCommandCapture('git', ['-C', ProjectDir, 'rev-parse', '--is-inside-work-tree'],
    '', OutText, ErrText, ExitCode) then
    Exit(True);
  if (ExitCode <> 0) or (Pos('true', LowerCase(OutText)) = 0) then
    Exit(True);

  if not RunCommandCapture('git', ['-C', ProjectDir, 'status', '--porcelain'],
    '', OutText, ErrText, ExitCode) then
  begin
    ErrorMsg := 'Could not read git status.';
    Exit(False);
  end;
  if ExitCode <> 0 then
  begin
    ErrorMsg := Trim(ErrText);
    Exit(False);
  end;
  if Trim(OutText) = '' then
    Exit(True);

  if not RunCommandCapture('git', ['-C', ProjectDir, 'add', '-A'],
    '', OutText, ErrText, ExitCode) then
  begin
    ErrorMsg := 'Could not stage project changes.';
    Exit(False);
  end;
  if ExitCode <> 0 then
  begin
    ErrorMsg := Trim(ErrText);
    Exit(False);
  end;

  if not RunCommandCapture('git',
    ['-C', ProjectDir, 'commit', '-m', 'Export snapshot'],
    '', OutText, ErrText, ExitCode) then
  begin
    ErrorMsg := 'Could not create export commit.';
    Exit(False);
  end;
  if ExitCode <> 0 then
  begin
    if Pos('nothing to commit', LowerCase(ErrText + OutText)) > 0 then
      Exit(True);
    ErrorMsg := Trim(ErrText);
    if ErrorMsg = '' then
      ErrorMsg := Trim(OutText);
    Exit(False);
  end;

  Result := True;
end;

end.
