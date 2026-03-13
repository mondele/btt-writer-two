# Import/Export Implementation

## Context

BTT-Writer Two needs import/export functionality matching v1. Currently: .tstudio export works (from project details dialog), import menu is stubbed. We need .tstudio import, USFM export, server upload/download, USFM import, and source text import. PDF export is deferred (v1 used commercial Prince PDF tool).

## Scope

**In:** .tstudio import with duplicate detection (overwrite), USFM export, server upload (HTTPS git push), server import (search + clone), USFM import (parse + create project), source text import, import options dialog, export options dialog.

**Out:** PDF export, merge conflict resolution (overwrite only for now), markdown/text export.

## Existing Infrastructure

- `TStudioPackage.pas` — `CreateTStudioPackage()`, `ExtractTStudioPackage()`, `ReadTStudioPackageInfo()`, `RunCommandCapture()`, `EnsureProjectCommitted()`, `ShellQuote()` (last 3 are in `implementation` section, not exported)
- `MainForm.pas` — `MenuImportClick` stub, `btnExportClick` in `TProjectDetailsWindow` (exports .tstudio only)
- `GiteaClient.pas` — token auth (login/logout), no git remote operations
- `ProjectCreator.pas` — `CreateProjectFromSource()`, `BuildManifestJSON()`
- `ProjectManager.pas` — `LoadContent()`, `SaveContent()`, `CommitProjectChanges()`
- `USFMUtils.pas` — `FindVerseMarkerPos()`, `ParseVerseNumbers()`, `UsxToPlainText()`
- `UserProfile.pas` — `TUserProfile` with `.Token`, `.Username`, `.ServerURL`

## Phase 1: Shared Git Utilities + USFM Export — COMPLETE

### 1a. `GitUtils.pas` — New shared unit

Extract from `TStudioPackage.pas` implementation section into a shared interface:

```pascal
function RunCommandCapture(const Exe: string; const Args: array of string;
  const WorkDir: string; out OutputText, ErrorText: string;
  out ExitCode: Integer): Boolean;
function EnsureProjectCommitted(const ProjectDir: string; out ErrorMsg: string): Boolean;
function ShellQuote(const S: string): string;
```

Update `TStudioPackage.pas` to `uses GitUtils` and remove the duplicated implementations.

### 1b. `USFMExporter.pas` — New unit

```pascal
function ExportProjectToUSFM(const ProjectDir, SourceContentDir, OutputPath: string;
  out ErrorMsg: string): Boolean;
```

Algorithm:
1. Load project via `TProject` + `LoadContent(SourceContentDir)`
2. Read manifest for book code, book name, resource name
3. Write USFM header: `\id {BOOK} {resource}`, `\ide usfm`, `\h {title}`, `\toc1`/`\toc2`/`\toc3`, `\mt {title}`
4. For each chapter: write `\c {num}` + `\p`, then concatenate all chunk contents (already USFM with `\v` markers)
5. Read book title from `front/title.txt` if it exists
6. Save to `OutputPath` via `TStringList.SaveToFile`

### 1c. Export options dialog in `MainForm.pas`

Replace the direct .tstudio save in `TProjectDetailsWindow.btnExportClick` with an export options dialog offering:
- "Upload to Server" (disabled if local user — enabled in Phase 3)
- "Export to Project File (.tstudio)" — existing flow
- "Export to USFM (.usfm)" — new, calls `ExportProjectToUSFM`

Simple modal `TForm` with 3 option buttons + Cancel. Returns enum `TExportChoice`.

**Files:** New `GitUtils.pas`, new `USFMExporter.pas`, modify `TStudioPackage.pas` (remove extracted functions, add `uses GitUtils`), modify `MainForm.pas` (export dialog + USFM save dialog), modify `bttwriter2.lpi`/`.lpr`.

## Phase 2: Import Dialog + .tstudio Import — COMPLETE

### 2a. `ImportForm.pas` — New unit

Modal import options dialog with 4 clickable option panels:
1. "Import from Server" (disabled if local user — enabled in Phase 3)
2. "Import Project File" (.tstudio)
3. "Import USFM File" (enabled in Phase 4)
4. "Import Source Text" (enabled in Phase 4)

Returns `TImportChoice = (icNone, icServer, icProject, icUSFM, icSourceText)`.

### 2b. .tstudio import logic in `MainForm.pas`

```pascal
procedure TMainWindow.DoImportProjectFile;
```

Flow:
1. `TOpenDialog` with `*.tstudio` filter
2. `ReadTStudioPackageInfo()` to get project path
3. Check if `GetTargetTranslationsPath + Info.ProjectPath` already exists
4. If exists: show overwrite/cancel dialog (simple `MessageDlg` with `mbYes`/`mbNo`)
5. If overwrite: delete existing directory
6. `ExtractTStudioPackage(path, GetTargetTranslationsPath, ...)` — already implemented
7. Verify manifest.json exists in extracted dir
8. Ensure git repo is valid (init if needed)
9. `ScanAndDisplayProjects` to refresh home screen
10. Show success message

### 2c. Wire `MenuImportClick`

Replace stub with:
```pascal
case ShowImportDialog of
  icProject: DoImportProjectFile;
  icUSFM: DoImportUSFMFile;       // Phase 4
  icServer: DoImportFromServer;   // Phase 3
  icSourceText: DoImportSourceText; // Phase 4
end;
```

**Files:** New `ImportForm.pas`, modify `MainForm.pas` (import menu handler + .tstudio import), modify `bttwriter2.lpi`/`.lpr`.

## Phase 3: Server Upload + Server Import — COMPLETE

### 3a. Extend `GiteaClient.pas`

New Gitea API functions:

```pascal
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
```

Gitea endpoints:
- `POST /api/v1/user/repos` — create repo (`{"name":"...","auto_init":false,"private":false}`)
- `GET /api/v1/repos/{owner}/{repo}` — check existence
- `GET /api/v1/repos/search?q={query}&limit=50` — search

### 3b. Server upload in `MainForm.pas`

```pascal
procedure TMainWindow.DoUploadToServer;
```

Flow:
1. Validate `IsServerUser(FUserProfile)` — must have token
2. Compute repo name from project dir name (e.g., `ru_psa_text_ulb`)
3. `EnsureProjectCommitted(ProjectDir)`
4. `GiteaRepoExists` → if not, `GiteaCreateRepo`
5. Set git remote: `git -C {dir} remote add origin https://{token}@{host}/{user}/{repo}.git` (or `set-url` if exists)
6. Push: `git -C {dir} push -u origin master`
7. Show success/failure

HTTPS with embedded token avoids SSH key management. Token from `FUserProfile.Token`, server from `FUserProfile.ServerURL` or `GetEffectiveDataServer`.

### 3c. Server import UI + logic

Uses `InputQuery` for search term, then `GiteaSearchRepos`, then a selection dialog with `TListBox`.

```pascal
procedure TMainWindow.DoImportFromServer;
```

Flow:
1. Show search input dialog
2. User searches, selects a repo
3. Compute target path: `GetTargetTranslationsPath + RepoName`
4. Check for existing project → overwrite/cancel
5. `git clone https://{token}@{host}/{owner}/{repo}.git {targetPath}`
6. Verify manifest.json
7. Refresh project list

**Files:** Modify `GiteaClient.pas`, modify `MainForm.pas` (upload + server import), modify `bttwriter2.lpi`/`.lpr`.

## Phase 4: USFM Import + Source Text Import — COMPLETE

### 4a. USFM parser in `USFMUtils.pas`

```pascal
type
  TUSFMVerse = record
    Chapter: Integer;
    Verse: Integer;
    Content: string;   { raw text including \v marker }
  end;
  TUSFMVerseArray = array of TUSFMVerse;

  TUSFMParseResult = record
    BookID: string;      { from \id line }
    BookTitle: string;   { from \h or \mt }
    Verses: TUSFMVerseArray;
  end;

function ParseUSFMFile(const FilePath: string; out ParseResult: TUSFMParseResult;
  out ErrorMsg: string): Boolean;
```

Parser reads line-by-line, tracks current chapter via `\c`, extracts `\id` for book code, `\h`/`\mt` for title, builds verse array from `\v` markers. Unknown markers passed through as literal text content.

### 4b. USFM import flow in `MainForm.pas`

```pascal
procedure TMainWindow.DoImportUSFMFile;
```

Flow:
1. `TOpenDialog` for `.usfm`/`.txt` file
2. `ParseUSFMFile()` to get book ID + verses
3. Validate book ID is canonical
4. Prompt for target language (reuse `PromptForTargetLanguage` from `ProjectCreator`)
5. Prompt for source text (reuse `PromptForSourceText`)
6. Create project via `CreateProjectFromSource`
7. Write parsed verses into chunk files
8. Git commit
9. Refresh project list

### 4c. Source text import in `MainForm.pas`

```pascal
procedure TMainWindow.DoImportSourceText;
```

Flow:
1. `TSelectDirectoryDialog` to pick resource container directory
2. Validate: `package.json` + `content/toc.yml` exist
3. Read `package.json` to get canonical name
4. Copy directory to `GetLibraryPath + canonicalName`
5. Show success message

**Files:** Modify `USFMUtils.pas` (add parser), modify `MainForm.pas` (USFM import + source text import).

## Implementation Order

| Step | What | Status |
|------|------|--------|
| 1 | Create `GitUtils.pas`, refactor `TStudioPackage.pas` | COMPLETE |
| 2 | Create `USFMExporter.pas` | COMPLETE |
| 3 | Add export options dialog to `MainForm.pas` | COMPLETE |
| 4 | Create `ImportForm.pas` | COMPLETE |
| 5 | Implement .tstudio import in `MainForm.pas` | COMPLETE |
| 6 | Extend `GiteaClient.pas` with repo API | COMPLETE |
| 7 | Implement server upload in `MainForm.pas` | COMPLETE |
| 8 | Implement server import UI + clone | COMPLETE |
| 9 | Add USFM parser to `USFMUtils.pas` | COMPLETE |
| 10 | Implement USFM import flow in `MainForm.pas` | COMPLETE |
| 11 | Implement source text import in `MainForm.pas` | COMPLETE |
| 12 | Register units, build, test | COMPLETE (compiles clean) |

## Key Design Decisions

- **HTTPS with token** for git push/clone — `https://{token}@{server}/{user}/{repo}.git` — avoids SSH key management, works cross-platform, token already available from login
- **Overwrite only** for duplicate projects — merge (git pull + manifest union) is complex; add later
- **Shell commands for git/zip** — established pattern via `RunCommandCapture` (Windows needs git in PATH, same as v1)
- **Export dialog in project details** — keeps export contextual; import is in main menu (matching v1)
- **No PDF export** — v1 used commercial Prince PDF; can add later with wkhtmltopdf or FPC PDF library
- **USFM parser is minimal** — handles `\id`, `\c`, `\v`, `\h`, `\mt`, `\p`, `\s`, `\d`; passes unknown markers through

## New Files

| File | Purpose |
|------|---------|
| `GitUtils.pas` | Shared `RunCommandCapture`, `EnsureProjectCommitted`, `ShellQuote` |
| `USFMExporter.pas` | Generate .usfm file from project content |
| `ImportForm.pas` | Import options dialog (4 choices) + Export options dialog (3 choices) |

## Modified Files

| File | Changes |
|------|---------|
| `TStudioPackage.pas` | Remove extracted functions, `uses GitUtils` |
| `ProjectCreator.pas` | Remove duplicated `RunCommandCapture`, `uses GitUtils` |
| `MainForm.pas` | Import menu handler, export options dialog, upload, server import, USFM import, source text import |
| `GiteaClient.pas` | Add `GiteaCreateRepo`, `GiteaRepoExists`, `GiteaSearchRepos`, `TGiteaRepoInfo` |
| `USFMUtils.pas` | Add `ParseUSFMFile`, `TUSFMParseResult`, `TUSFMVerseArray` |
| `bttwriter2.lpi` | Register new units |
| `bttwriter2.lpr` | Add new units to uses clause |

## Verification

1. `lazbuild bttwriter2.lpi` — compiles clean after each phase ✓
2. Export: Open project details → Export → choose USFM → verify `.usfm` file has correct headers + verse content
3. Export: Open project details → Export → choose .tstudio → still works as before
4. Import: Menu → Import → Import Project File → select `.tstudio` → project appears in list
5. Import duplicate: Import same `.tstudio` again → overwrite dialog → project replaced
6. Server upload: Export → Upload to Server → repo created on configured server, push succeeds
7. Server import: Import → Import from Server → search by username → clone succeeds → project appears
8. USFM import: Import → Import USFM → select file → prompted for language/source → project created with correct chunks
9. Source text import: Import → Import Source Text → select resource container dir → copied to library
