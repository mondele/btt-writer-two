unit SourceExtractor;

{$mode objfpc}{$H+}

interface

{ Extract a .tsrc entry from the bundled resource_containers.zip into DestDir.
  TsrcSlug is the resource slug without path or extension (e.g. 'en_mat_ulb').
  Returns True on success. Pure Pascal — no external tools required. }
function ExtractTsrc(const ZipPath, TsrcSlug, DestDir: string): Boolean;

{ Find the bundled resource_containers.zip. Checks install path first,
  then falls back to .claude/assets/ for development. Returns '' if not found. }
function FindBundledZipPath: string;

implementation

uses
  Classes, SysUtils, Zipper, bzip2stream, libtar,
  DataPaths, AppLog;

function FindBundledZipPath: string;
var
  InstallPath, DevPath: string;
begin
  { Check install location first }
  InstallPath := GetBundledResourceContainersZipPath;
  if FileExists(InstallPath) then
    Exit(InstallPath);

  { Dev-mode fallback: .claude/assets/ relative to executable }
  DevPath := ExtractFilePath(ParamStr(0)) + '.claude' + DirectorySeparator +
    'assets' + DirectorySeparator + 'resource_containers.zip';
  if FileExists(DevPath) then
    Exit(DevPath);

  Result := '';
end;

{ Step 1: Extract the .tsrc entry from the zip into a memory stream. }
function ExtractTsrcFromZip(const ZipPath, TsrcSlug: string;
  OutStream: TMemoryStream): Boolean;
var
  Unzipper: TUnZipper;
  EntryName: string;
  TempDir, TempFile: string;
begin
  Result := False;
  EntryName := 'resource_containers/' + TsrcSlug + '.tsrc';

  { TUnZipper extracts to disk, so use a temp directory }
  TempDir := IncludeTrailingPathDelimiter(GetTempDir) + 'bttw_tsrc_' + TsrcSlug;
  ForceDirectories(TempDir);

  Unzipper := TUnZipper.Create;
  try
    Unzipper.FileName := ZipPath;
    Unzipper.OutputPath := TempDir;
    Unzipper.Flat := True;  { strip directory structure }
    Unzipper.Files.Add(EntryName);
    try
      Unzipper.UnZipAllFiles;
    except
      on E: Exception do
      begin
        LogFmt(llError, 'Failed to extract %s from zip: %s', [EntryName, E.Message]);
        Exit;
      end;
    end;

    TempFile := IncludeTrailingPathDelimiter(TempDir) + TsrcSlug + '.tsrc';
    if not FileExists(TempFile) then
    begin
      LogFmt(llError, 'Extracted file not found: %s', [TempFile]);
      Exit;
    end;

    OutStream.LoadFromFile(TempFile);
    OutStream.Position := 0;
    Result := True;
  finally
    Unzipper.Free;
    { Clean up temp file }
    if FileExists(TempFile) then
      DeleteFile(TempFile);
    RemoveDir(TempDir);
  end;
end;

{ Step 2: Bzip2-decompress a stream into another stream. }
function DecompressBzip2(InStream: TStream; OutStream: TMemoryStream): Boolean;
var
  Decomp: TDecompressBzip2Stream;
  Buf: array[0..65535] of Byte;
  BytesRead: LongInt;
begin
  Result := False;
  InStream.Position := 0;
  Decomp := TDecompressBzip2Stream.Create(InStream);
  try
    try
      repeat
        BytesRead := Decomp.Read(Buf[0], SizeOf(Buf));
        if BytesRead > 0 then
          OutStream.Write(Buf[0], BytesRead);
      until BytesRead = 0;
      OutStream.Position := 0;
      Result := True;
    except
      on E: Exception do
        LogFmt(llError, 'Bzip2 decompression failed: %s', [E.Message]);
    end;
  finally
    Decomp.Free;
  end;
end;

{ Step 3: Extract a tar stream to a directory. }
function ExtractTar(TarStream: TStream; const DestDir: string): Boolean;
var
  TA: TTarArchive;
  DirRec: TTarDirRec;
  EntryPath, EntryDir: string;
  FS: TFileStream;
  MS: TMemoryStream;
begin
  Result := False;
  TarStream.Position := 0;
  TA := TTarArchive.Create(TarStream);
  try
    try
      while TA.FindNext(DirRec) do
      begin
        EntryPath := IncludeTrailingPathDelimiter(DestDir) +
          StringReplace(DirRec.Name, '/', DirectorySeparator, [rfReplaceAll]);

        if DirRec.FileType = ftDirectory then
        begin
          ForceDirectories(EntryPath);
          Continue;
        end;

        { Ensure parent directory exists }
        EntryDir := ExtractFileDir(EntryPath);
        if EntryDir <> '' then
          ForceDirectories(EntryDir);

        { Extract file using TStream overload }
        if DirRec.FileType = ftNormal then
        begin
          MS := TMemoryStream.Create;
          try
            TA.ReadFile(MS);
            MS.Position := 0;
            FS := TFileStream.Create(EntryPath, fmCreate);
            try
              FS.CopyFrom(MS, MS.Size);
            finally
              FS.Free;
            end;
          finally
            MS.Free;
          end;
        end;
      end;
      Result := True;
    except
      on E: Exception do
        LogFmt(llError, 'Tar extraction failed: %s', [E.Message]);
    end;
  finally
    TA.Free;
  end;
end;

function ExtractTsrc(const ZipPath, TsrcSlug, DestDir: string): Boolean;
var
  BzStream, TarStream: TMemoryStream;
begin
  Result := False;
  LogFmt(llInfo, 'ExtractTsrc: slug=%s dest=%s', [TsrcSlug, DestDir]);

  BzStream := TMemoryStream.Create;
  TarStream := TMemoryStream.Create;
  try
    { Step 1: Extract .tsrc from zip }
    if not ExtractTsrcFromZip(ZipPath, TsrcSlug, BzStream) then
    begin
      LogError('ExtractTsrc: failed to extract .tsrc from zip');
      Exit;
    end;
    LogFmt(llInfo, 'ExtractTsrc: got %d bytes of bzip2 data', [BzStream.Size]);

    { Step 2: Bzip2 decompress }
    if not DecompressBzip2(BzStream, TarStream) then
    begin
      LogError('ExtractTsrc: bzip2 decompression failed');
      Exit;
    end;
    LogFmt(llInfo, 'ExtractTsrc: decompressed to %d bytes of tar data', [TarStream.Size]);

    { Step 3: Extract tar to destination }
    ForceDirectories(DestDir);
    if not ExtractTar(TarStream, DestDir) then
    begin
      LogError('ExtractTsrc: tar extraction failed');
      Exit;
    end;

    { Verify package.json exists }
    Result := FileExists(IncludeTrailingPathDelimiter(DestDir) + 'package.json');
    if Result then
      LogInfo('ExtractTsrc: success — package.json found')
    else
      LogWarn('ExtractTsrc: extraction completed but package.json not found');
  finally
    TarStream.Free;
    BzStream.Free;
  end;
end;

end.
