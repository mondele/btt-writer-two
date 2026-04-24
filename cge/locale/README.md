# BTT-Writer CGE translations

## Workflow

**Source of truth**: all user-visible CGE strings live as FPC
`resourcestring` declarations in `cge/code/CGEStrings.pas`.

**Extract template** (`.pot`): run
`cge/scripts/extract-pot.sh`. That script builds the project so FPC
emits `.rsj` files, then runs `rstconv` on each and merges the results
into `cge/locale/btt-writer-cge.pot`.

**Translate**: upload `btt-writer-cge.pot` to Crowdin. Translators
produce per-language files like `btt-writer-cge.fr.po`,
`btt-writer-cge.ar.po`, etc.

**Ship**: drop the completed `.po` files into this directory. Runtime
wiring (TranslateResourceStrings / gettext) is not yet in place — see
below.

## Requirements

- FPC 3.2.2 or newer
- Castle Game Engine 7.0-alpha.3+
- `rstconv` (shipped with FPC as `/usr/bin/rstconv`)

Set the env var `CASTLE_ENGINE` to override the castle-engine binary
path if it's not on `$PATH`.

## Status

- [x] `CGEStrings.pas` declares all strings used by recent views
- [x] `.pot` generation works end-to-end
- [ ] Full migration of every existing CGE view (in progress —
      completed: Terms; pending: Home, Login, Settings, New Project,
      Import, Feedback, Editor, Read, BlindEdit, ChunkEdit)
- [ ] Runtime `.po` loading (gettext) — a user-selected language
      should load the matching `.mo` at startup via
      `TranslateResourceStrings`.
- [ ] RTL layout mirroring for Arabic/Hebrew/etc. — currently tracked
      as its own task (see PROJECT.md §"Full RTL layout mirroring").
- [ ] Complex-script font fallback — Noto Sans covers Latin/Cyrillic/
      Greek; other scripts need additional Noto families loaded as
      fallbacks on the `TCastleFontFamily`.
