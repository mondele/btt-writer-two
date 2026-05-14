# Auto-Save & Chunk Lifecycle

## Context

Per `PROJECT.md`: a chunk should be written to disk when editing is
disabled, when the editor loses focus, or after five minutes — whichever
happens first. Marking a chunk *finished* persists to
`manifest.json` and disables further editing until un-marked.

The current `ProjectEditForm` has most of the plumbing already wired:

| Spec requirement | Status |
|------------------|--------|
| 5-minute timer save | ✓ `AutoSaveTimer.Interval=300000` (LFM), calls `SaveCurrentChapter` |
| Memo loses focus → save | ✓ `OnChunkMemoExit` → `SaveCurrentChapter` when `FChapterDirty` |
| Editing disabled → save | ✗ `SetEditing(False)` only calls in-memory `SaveContent`; no chapter write |
| Marked finished → manifest persisted | partial — `MarkFinished` writes manifest, but doesn't flush in-progress memo content first |
| Finished disables editing | ✓ `SetEditing` early-exits when `FFinishedCheck.Checked` |
| Unfinished re-enables editing | ✓ via `MarkUnfinished` (manifest path); UI path needs audit |
| Auto-save status indicator | ✓ `lblStatus` updates with timestamp |
| Disk write of finished_chunks | ✓ `SaveManifest` → `SL.SaveToFile(FManifestPath)` |

So the bulk of the design exists. The work is gap-fixing and verification, not greenfield.

## Goals

1. Guarantee no edited content is silently lost when a user toggles edit-off, marks finished, closes a project, or switches chapters.
2. Manifest `finished_chunks` is always consistent with on-disk chunk files (no stale "finished" pointing at unflushed memo content).
3. Visible feedback when a save fails; user is not stuck in a broken state.

## Phases

| # | What | Status |
|---|------|--------|
| 1 | Audit. Memo OnExit ✓, LoadChapter switch ✓, AutoSaveTimer ✓, FormClose ✓ all flush. `SetEditing(False)` and `OnChunkFinishedChange` did NOT. `OnMenuMarkAllDone` is a stub | COMPLETE |
| 2 | `TChunkPanel.SetEditing(False)` now calls `FOwnerForm.SaveCurrentChapter` after the in-memory `SaveContent`. The chunk .txt files now match the visible state at the moment the user toggles edit off | COMPLETE |
| 3 | `OnChunkFinishedChange` reordered: flush in-progress memo via `SetEditing(False)` (which now disk-writes per Phase 2) BEFORE `MarkFinished` mutates manifest. Manifest never references unsaved text | COMPLETE |
| 4 | `MarkUnfinished` symmetry: existing code re-enables FEditButton and refreshes visuals — verified during audit, no fix needed | COMPLETE |
| 5 | `AutoSaveTimerFire` failure no longer force-closes the window. Logs `llWarn`, surfaces error via `lblStatus`. Transient disk pressure no longer destroys session state | COMPLETE |
| 6 | Smoke test. Walk all five trigger paths in the running app: focus loss, edit-toggle, finished-toggle, chapter switch, 5-min tick. Verify each writes the `.txt` chunk file *and* `manifest.json` finished_chunks where applicable | PENDING |

## Files

**Modified (expected):**
- `ProjectEditForm.pas` — `SetEditing`, `OnChunkFinishedChange`, `AutoSaveTimerFire` adjustments
- `ProjectManager.pas` — possibly small helpers; `MarkFinished` likely unchanged
- `PLAN.md` — phase status updates

**No new files anticipated.**

## Key Design Decisions

- **Save before flip, not after.** Any state transition that marks a chunk finished or hides the edit memo must flush content first, then mutate manifest. Otherwise a power loss between flip and save leaves manifest claiming "finished" against stale text.
- **No new abstractions.** Re-use existing `SaveCurrentChapter` / `SaveContent` / `MarkFinished`. Code shape stays close to today.
- **Status-bar feedback, not modal popups.** Auto-save shouldn't interrupt typing with a dialog on every transient failure.

## Verification

1. `lazbuild bttwriter2.lpi` clean after each phase
2. Edit a chunk, switch chapter mid-type → reopen → text intact
3. Edit a chunk, toggle edit-off → reload project → text intact
4. Edit a chunk, mark finished → reload project → finished_chunks contains the key, chunk text intact, edit button disabled
5. Unmark finished → edit button re-enabled, edit content intact
6. Wait 5 min while idle → status shows auto-save timestamp
7. Force a save failure (e.g., chmod project dir read-only) → status shows error, app doesn't crash
