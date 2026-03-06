# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

BTT-Writer Two is a rewrite of BTT-Writer Desktop (Electron/JavaScript) in Free Pascal / Lazarus. It is a cross-platform Bible translation editor supporting an eight-step translation workflow, with "chunking" (Step 3) as the central feature. Targets Linux, Windows, macOS, and potentially Android.

Development is on Linux. The project is in early planning phase — see `PROJECT.md` for the full specification.

## Recent Codex Work Log (For Claude Review)

The following commits were implemented by Codex and should be the primary audit targets:

- `ac7ab65` `[codex] Force white status text via owner-drawn home status bar`
  - Home status bar panel 0 is owner-drawn to force readable text color on GTK/light theme.
  - Reason: `TStatusBar.Font.Color` was not respected by the platform theme.
- `b5f7e8f` `[codex] Set UI/content fonts and status bar sizing/colors`
  - Added `UIFonts.pas` with recursive `ApplyFontRecursive(...)`.
  - Applied `Noto Sans` across UI forms (home, project edit, settings, splash).
  - Set source/translation default text controls to `Roboto`.
  - Set status bar minimum heights to 30px on main and project edit forms.
- `737aa8a` `[codex] Align app theme colors to provided CSS palette`
  - Updated Lazarus theme values to match provided CSS light/dark color targets.
- `8f16890` `[codex] Centralize light/dark color palette in shared theme unit`
  - Added/used centralized theme palette for form-level application.
- `7772c3d` `[codex] Close splash after first home screen load`
  - Splash now closes on first successful project scan/render.
- `f0c4302` `[codex] Convert UI strings to resourcestrings for localization`
  - UI strings moved toward i18n-ready `resourcestring` usage.

Notes for audit:
- There is one non-codex commit in this range: `65c704c` (`Update form branding colors and add project edit sidebar`), created per user request without codex tag.
- Known untracked local artifacts may exist during dev (`GTAGS`, `GRTAGS`, `GPATH`) and are not part of app behavior.

## Related Codebases

These sibling directories serve as references:

- **`../chunkCounter/`** — Working Free Pascal/Lazarus tool that loads and compares BTT-Writer resource containers. Its data model (TBook → TChapter → TChunk) and units (BibleBook.pas, BibleChapter.pas, etc.) are the architectural starting point for this project. See its own `CLAUDE.md` for details.
- **`../BTT-Writer-Desktop/`** — The Electron app being replaced. Reference for UI behavior, data formats, and backward-compatibility requirements. Run with `npm start`; test with `gulp test`.

## Build Commands

Requires Free Pascal Compiler and Lazarus (lazbuild 4.0+).

```bash
# Build a Lazarus project
lazbuild <project>.lpi
```

## Architecture & Key Concepts

### Data Paths (DATA PATH)

Platform-specific base directory for all BTT-Writer data:
- **Linux**: `~/.config/BTT-Writer/`
- **macOS**: `~/Library/Application Support/BTT-Writer/`
- **Windows**: `%APPDATA%\Local\BTT-Writer\`

Structure under DATA PATH:
```
BTT-Writer/
├── library/resource_containers/    # Source texts (installed on demand)
├── targetTranslations/             # User's translation projects (git repos)
└── index/resource_containers/      # Bundled compressed archives
```

### Source Texts

Stored in `DATA PATH/library/resource_containers/` with directory naming: `{langCode}_{bookCode}_{resourceType}` (e.g., `en_act_ulb`).

Each contains:
- `content/` — chapter directories (01…n) with `.usx` files, plus `front/title.usx`
- `content/toc.yml` — chunk structure definition
- `content/config.yml` — important words mapping
- `package.json`, `LICENSE.md`

### Target Translations (Projects)

Stored in `DATA PATH/targetTranslations/` as git repositories. Directory naming: `{langCode}_{bookCode}_text_{resourceType}` (e.g., `en_act_text_ulb`).

Each contains: `manifest.json` (book info, contributors, source, finished chunks), chapter directories with chunk `.txt` files (USFM format, named by first verse: `01.txt`, `04.txt`), and `front/` for book title.

### Core Chunking Design

This is the critical architectural requirement:

1. **On load**: Stream all chunk files into a single in-memory text per chapter
2. **On display**: Split text into chunks based on the *current source text's* chunking (from `toc.yml`), not the stored file boundaries
3. **On save**: Write back to disk split into *English ULB* chunks (for backward compatibility), regardless of display chunking

This decouples display chunking from storage chunking, enabling different source languages to use different chunk boundaries while maintaining interoperability.

### Chunk States & Behavior

- **Open for editing**: Simple text editor, verse markers shown as USFM (`\v 1`)
- **Closed (not finished)**: Read-only display, verse markers as colored balloons (movable by user)
- **Marked finished**: Read-only, editing disabled until un-marked

Auto-save triggers: editor loses focus, editing disabled, or 5-minute timeout. Finished/unfinished status is persisted in `manifest.json`.

### Translation Context Pane

A side pane (right for LTR, left for RTL) shows translationWords, questions, and notes relevant to the current chunk's verses.

## UI Reference

Screenshots of the existing BTT-Writer Desktop are in `.claude/screenshots/`. The app uses a blue header bar, white content area, and blue left sidebar with a vertical three-dot menu. Key screens and navigation flow:

### Authentication Flow
- **User Profile** (`login-en.png`) — Three options: Login to Server Account, Create Server Account, Create Local User Profile
- **Server Login** (`server-login-en.png`) — Username/password form with internet warning, "Create a New Account" link
- **Local Login** (`local-login-en.png`) — Single "Full Name or Pseudonym" field, with "Login with Server Account" link
- **Terms of Use** (`terms-en.png`) — Shown after login. Three green buttons (License Agreement, Translation Guidelines, Statement of Faith) with Agree/Decline

### Home Screen
- **Empty state** (`home-en.png`) — Welcome message with "Start a New Project" button. Header shows "Current User: «username» (Logout)". Green circular "+" button top-right
- **With projects** (`project-list-en.png`) — Sortable table: Project name, Type, Language, Progress (pie chart), info button. Two sort dropdowns: "Columns to Sort By" and "Sort Project Column By"

### Main Menu (three-dot icon, bottom-left)
- (`home-menu-en.png`) — Update, Import, translationAcademy, Feedback, Logout, Settings

### New Project / Source Text Flow
- **Source language list** (`select-source-language-en.png`) — Breadcrumb: Home > Source Texts > By Language. Searchable language list showing name and code (e.g., "Amharic (am)")
- **Testament selection** (`select-testament-en.png`) — Old Testament, New Testament, Other
- **Book & version selection** (`select-book-version-en.png`) — Checkboxes for each book+version combo (e.g., "Matthew (mat) — Unlocked Literal Bible (ulb)"). Select All / Unselect All with Download button

### Import
- **Import options** (`import-menu-en.png`) — Four choices: Import from Server, Import Project File, Import USFM File, Import Source Text
- **Import from Server** (`import-from-server-en.png`, `book-or-language-en.png`) — Search by username and book/language code, results table with User Name and Project Name

### Settings
- **General** (`settings-1-en.png`) — Interface Language selector, Gateway Language Mode checkbox, Blind Edit Mode checkbox
- **About** (`settings-3-en.png`) — Backup Location, App Version, Git Version, Data Path, Legal section

### Feedback
- (`feedback-form-en.png`) — Simple dialog: internet warning, multiline text area, Cancel/Send buttons

## New Features (Beyond Legacy BTT-Writer)

- **External import invocation** — The import function must be callable from the command line, enabling integration with scripts and other tools.
- **File association for .tstudio** — Double-clicking a `.tstudio` file should open the program and import the project. Requires OS-level file type registration (desktop entry with MimeType on Linux, file association on Windows/macOS).
- **Full RTL layout mirroring** — The entire UI must flip horizontally for right-to-left script systems (e.g., Arabic, Hebrew). This goes beyond text direction — pane positions, navigation, and layout flow should all mirror.

## Legacy Documentation

The existing (somewhat dated) docs are at https://btt-writer.readthedocs.io/en/latest/. Key behavioral details from the Desktop docs that inform this rewrite:

### Translation Views (Text Projects)

Three view modes, toggled via icons in the project screen:

1. **Blind Edit** — Shows source one chunk at a time. Translator clicks the blank card behind the source to type their translation. Source and translation are never visible simultaneously. Used for initial drafting.
2. **Edit-Review** — Three-pane layout: source text (left), editable translation (middle), tabbed resources (right: Notes, Words, Questions, UDB). Pencil icon to edit a chunk, checkmark to save. Verse markers are dragged into position. Completion toggle at chunk bottom.
3. **Read** — Full chapter display, read-only. Click "paper behind source text" to switch between source and translation views.

### Project Types

Beyond plain text translation, BTT-Writer supports:
- **Words projects** — Translate translationWords terms and definitions. Two-pane: English definition (left), working area (right) with red divider between word translation and definition translation. Navigation by letter/word.
- **Notes projects** — Four-pane: source, read-only translation, working notecards, resources. Each note becomes a notecard with reference above and note text below a red divider.
- **Questions projects** — Same four-pane layout as Notes. Question above red line, answer below.
- **Gateway Language Mode** — When enabled, adds resource translation options (Notes, Questions) alongside text translation (ULB, UDB).

### New Project Setup

Requires three selections: target language, project category (OT/NT/Other), and source text. Up to three source texts can be selected for side-by-side reference. Source texts are downloaded on demand from bundled archives.

### Import/Export Formats

- **Upload to server** — Pushes to WACS (Wycliffe Associates) or DCS (Door43) server
- **USFM export** — Standard `.usfm` file for interop with other Bible translation tools
- **PDF export** — Options: include incomplete chunks, double-space, justify, new page per chapter
- **Project file** — `.tstudio` format, compatible with BTT Writer Desktop and Android
- **Import from server** — Search by username or book/language code (e.g., `fr_eph`)
- **Merge conflicts** — On duplicate import: Cancel, Merge (shows green=original vs blue=imported for manual resolution), or Overwrite

### Settings

- General: Interface Language, Gateway Language Mode, Blind Edit Mode, font/size for source and target, backup location
- Advanced: Server Suite (WACS or DCS), Data Server, Media Server, Developer Tools
- About: App Version, Git Version, Data Path
- Legal: License Agreement, Statement of Faith, Translation Guidelines, Software Licenses, Attribution

### USFM Footnote Syntax

Footnotes in translated text use USFM codes: `\f + \ft ... \f*` with quoted text wrapped in `\fqa ... \fqa*`.

## Conventions

Inherited from chunkCounter:
- Compiler mode: `{$mode objfpc}{$H+}`
- PascalCase unit filenames (e.g., `BibleBook.pas`)
- `T` prefix for classes (e.g., `TBook`, `TChapter`)
- Platform conditionals: `{$IFDEF WINDOWS}` / `{$IFDEF DARWIN}` / `{$IFDEF LINUX}`
- Memory management: manual with `FreeAndNil`
- Collections: generic `FPGMap` and `TObjectList` from `Generics.Collections`
