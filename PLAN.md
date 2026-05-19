# Monolithic-USFM Project Storage

## Context

The current model treats per-chunk `<chapter>/<chunk>.txt` files as the canonical store. The application:

1. Reads chunk files at LoadChapter, merges into a single per-chapter text.
2. Splits the merged text by *source* chunking for display.
3. On save, re-merges display chunks, re-splits by *English ULB* chunking, writes chunk files.

That round trip has produced a string of corruption bugs — verses migrating to the wrong chunk on missing/typoed markers, paste-without-marker gobbling forward, duplicate verses on edit-then-revert, stub markers leaking into chunk files. The recent fixes (verse-range routing, dedup-last, marker inference, post-save display refresh, trailing-stub stripping) each address a specific failure mode but leave the underlying asymmetry intact: in-memory state is rebuilt from a derivative every load and re-derived from display every save. Every cycle is a chance to corrupt.

Monolithic USFM-per-book is the **industry-standard exchange format** (Paratext, USFM ecosystem). Whole-book files are the norm; per-chapter files are an outlier. Per-write disk churn is not a concern at this scale — Bible books are kilobytes.

## Goal

Adopt a single `.usfm` file per book as the canonical store. Per-chunk `.txt` files become *derived* artifacts, written on save for backward compatibility with BTT-Writer Desktop / Android v1. Display chunking and edit-by-chunk UX are unchanged.

## On-Disk Layout

```
<projectdir>/
├── .usfm/
│   └── <NN>-<CODE>_<lngcode>.usfm    # canonical, one file for entire book
├── 01/                                # derived chunk files (v1 backward-compat)
│   ├── 01.txt
│   ├── 04.txt
│   └── …
├── 02/ …
├── front/
│   └── title.txt                      # derived from \h / \mt in monolithic
└── manifest.json
```

- `<NN>` = USFM canonical book number from `USFMBookNumber` in `MainForm.pas:265` (OT 01–39, skip 40, NT 41–67).
- `<CODE>` = USFM book code, uppercase (e.g. `JDG`).
- `<lngcode>` = target language code from manifest (e.g. `aa`).
- Example: `07-JDG_aa.usfm`.
- `.usfm/` is invisible to BTT-Writer v1 (it walks the chapter dirs; unknown leading-dot dirs are ignored).

## Architectural Shift

| Concern | Before | After |
|---------|--------|-------|
| Canonical store | per-chunk `.txt` files | `.usfm/<NN>-<CODE>_<lng>.usfm` |
| In-memory model | per-chapter text rebuilt every LoadChapter | parsed monolithic book, held for project lifetime |
| Edit | memo → FTransText (transient per-chapter) | memo → FTransText → patch in-memory monolithic |
| Save | merge display → re-split ULB → write all chunk files | write monolithic → derive chunks → write chunk files |
| Load | walk chunk files → merge → split source | read monolithic → extract chapter slice → split source. (Fallback path builds monolithic from chunks for first-time-open of v1 projects.) |
| Verification | none | every load: merge chunks, compare to monolithic, log/warn on divergence |

The fixed-point of the model is now the monolithic file. Display chunks are read-only derivations. The chunk `.txt` files are write-only derivations (the app never reads them at edit time after initial v1 import).

## Phases

| # | What | Status |
|---|------|--------|
| 1 | New unit `BookUsfm.pas` (or similar). `LoadMonolithic(Path) -> TBook`, `SaveMonolithic(Book, Path)`. Use existing `BibleBook`/`BibleChapter` types as the parsed model — extend if needed. | PENDING |
| 2 | Filename helper `MonolithicPath(ProjectDir, BookCode, LangCode): string` returning `<projectdir>/.usfm/<NN>-<CODE>_<lng>.usfm`. Reuses `USFMBookNumber`. | PENDING |
| 3 | `TProject.LoadContent` change: if monolithic exists, parse it into `FBook`. Otherwise build `FBook` from chunk files (legacy v1 path), then write the monolithic file so subsequent opens are fast. | PENDING |
| 4 | Verification pass at load: walk chunk files, build a comparison `TBook`, diff against monolithic. Mismatches → `LogWarn` + retain monolithic as truth. Optional UI affordance to view diff. | PENDING |
| 5 | `LoadChapter` change: extract chapter slice from in-memory monolithic instead of merging chunk files. Display split by source chunking unchanged. | PENDING |
| 6 | `SaveCurrentChapter` rework: integrate merged display text into the in-memory monolithic book (replacing that chapter's verses), then write the monolithic file, then derive `<chapter>/<chunk>.txt` files for v1 compat. The existing band-aids (dedup-last, marker inference, range routing, trailing-stub stripping) stay on the derivation path — defensive only, not load-bearing. | PENDING |
| 7 | Migrate `aa_jdg_text_reg`: open once with new code → monolithic gets built from existing chunks. Verify (manually compare). Then a clean save should normalize chunk files. | PENDING |
| 8 | Manifest flag `usfm_canonical: true` written when monolithic is present. Lets future code branches detect upgraded projects. (Not strictly required — file presence is enough — but useful for logging and future tooling.) | PENDING |
| 9 | Wire `RepairChapters` (future CLI verb per `PROJECT.md` planned CLI surface): walks the in-memory book and rewrites all chunk files. With monolithic as canon, repair becomes a one-line derivation. | PENDING |

## Key Design Decisions

- **Whole-book file**, not per-chapter. Matches Paratext and downstream tooling. Read cost is negligible.
- **Monolithic is canonical**. Chunk files are write-only derivations after the initial v1 import.
- **Backward-compatible chunk writes happen on every save.** Cheap (kilobytes), keeps v1 round-trip intact.
- **`.usfm/` is hidden from v1.** Leading dot makes the directory invisible to v1's chapter-dir scan.
- **No backwards-incompat manifest changes.** Existing keys retained; `usfm_canonical` is purely informational.
- **In-memory book held for project lifetime**, not rebuilt per chapter. Chapter-switch becomes cheap.

## Files

**New:**
- `BookUsfm.pas` — monolithic load/save + filename helper.

**Modified:**
- `BibleBook.pas` / `BibleChapter.pas` — possibly extend to track book-level USFM headers (`\h`, `\toc1`, `\mt`).
- `ProjectManager.pas` — `LoadContent` branches on monolithic presence; in-memory book held across edit session.
- `ProjectEditForm.pas` — `LoadChapter` reads from `FProject.Book`; `SaveCurrentChapter` integrates back, writes monolithic, then derives chunks.
- `manifest.json` schema — optional `usfm_canonical` flag.

**No new external dependencies.** USFM parsing is text-only; existing `USFMUtils` helpers cover what we need.

## Verification

1. `lazbuild bttwriter2.lpi` clean after each phase.
2. Open `aa_jdg_text_reg` (v1-shaped, no monolithic yet) → log shows "building monolithic from chunks" → `.usfm/07-JDG_aa.usfm` appears with all current content.
3. Reopen → log shows monolithic loaded, chunk diff = clean.
4. Edit chunk 6, change marker, save → monolithic updated, chunk files re-derived correctly, no duplicate verses anywhere.
5. Cut-and-paste between chunks: verses route correctly regardless of marker mishaps.
6. Open same project in v1 BTT-Writer Desktop → chunks render normally (v1 unaware of `.usfm/`).
7. Edit in v1, save → reopen in v2 → verification step flags divergence (since v1 only updated chunks), v2 prefers monolithic *unless* policy says "trust newer chunks". Decide policy during Phase 4.

## Risks & Open Questions

- **v1 wins, v2 loses?** If a user edits in v1 between v2 sessions, v2's monolithic is stale relative to chunks. Need a rule. Suggest: if monolithic mtime < any chunk mtime, rebuild monolithic from chunks at load (and log).
- **Title chunk** lives at `front/title.txt`. In USFM, the book title is `\h <name>` + `\toc1..3` + `\mt <name>`. Need a mapping at both ends.
- **Conflicts** during git merge of monolithic + chunks. Resolution: monolithic is canon, regenerate chunks. May need a manifest hook so the chunk regeneration step knows the file was just resolved.
- **Read-mode rendering**: currently reads chunk content. After this change, read mode should pull from in-memory monolithic for consistency.
