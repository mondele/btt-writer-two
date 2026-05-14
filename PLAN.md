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
| 1 | Audit. Trace every edit-exit path (`SetEditing(False)`, finished-toggle, edit-button toggle, chapter switch, project close) and document whether it currently flushes to disk. Output: short table in this PLAN | PENDING |
| 2 | Fix `SetEditing(False)` so it writes to disk. After in-memory `SaveContent`, set `FChapterDirty := True` on owner form and invoke `SaveCurrentChapter` directly (or queue via async call if Re-entrancy is a concern) | PENDING |
| 3 | Fix `MarkFinished` UI path. Before flipping the finished switch, force-flush any in-progress memo for that chunk: `if FEditing then SaveContent; OwnerForm.SaveCurrentChapter; OwnerForm.FProject.MarkFinished(...)`. Order matters — finished_chunks should never reference content that didn't make it to disk | PENDING |
| 4 | Audit `MarkUnfinished` symmetry. Toggle from finished back to unfinished should re-enable the edit button and refresh visuals. Verify no UI lag (e.g., `FFinishedCheck.OnChange` actually flips state, not just visual) | PENDING |
| 5 | Save-failure surfacing. `AutoSaveTimerFire` currently `ShowMessage` + `Close`. That's harsh for transient failures (disk full, lock contention). Consider: log error, show status-bar message, retry on next tick. Don't force-close unless N consecutive failures | PENDING |
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
