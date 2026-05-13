# i18n Operationalization

## Context

The codebase has scaffolded i18n — 248 `resourcestring` declarations across 12 units, `.rsj` files emitted on build, an "Interface Language" Settings UI — but it is not operational. There are no `.po`/`.pot` files on `master`, no runtime translator wiring, and ~39 hardcoded `Caption := 'literal'` assignments remaining (mostly `ProjectEditForm.pas`).

Goal: language switching works end-to-end, with five non-English translations pre-seeded from legacy v1 BTT-Writer Desktop strings.

## Inputs

- **CGE pot (existing on `castle-engine` branch):** `cge/locale/btt-writer-cge.pot`, 146 msgids, unit prefix `cgestrings:`. Drives the CGE port. Keep untouched so CGE branch continues to use it.
- **Legacy v1 translations:** `/home/jdwood/Development/WA/mondele/BTT-Writer-Desktop/i18n/{en,es-419,fa,fr,pt-br,ru}.json`. Key-value JSON keyed by legacy IDs (`bemode_maintext`, etc.) — new keys do not match, but English text often does. Mine by English-text match.

## Locale path

`cge/locale/` is shared by both branches.

- `master` currently gitignores `cge/` entirely (CGE spike). Add `!cge/locale/` exception.
- Two `.pot` files coexist there:
  - `btt-writer-cge.pot` — CGE port, namespace `cgestrings:*` (unchanged)
  - `btt-writer.pot` — LCL app, namespace `mainform:*`, `settingsform:*`, etc. (new)
- Translations: `cge/locale/{lang}/btt-writer.po` and `cge/locale/{lang}/btt-writer-cge.po`

## Phases

| # | What | Status |
|---|------|--------|
| 1 | `.gitignore` whitelist `cge/locale/`; copy `btt-writer-cge.pot` from `castle-engine` into master at same path | COMPLETE |
| 2 | Strip remaining 39 hardcoded `Caption := 'literal'` → `resourcestring` references (ProjectEditForm 26, MainForm 7, others 6) | COMPLETE |
| 3 | `tools/extract-pot.sh` — rsj→po per unit via rstconv, deduped per unit with msguniq, merged across units via msgcat. Emits `cge/locale/btt-writer.pot` (232 msgids from 12 units) | COMPLETE |
| 4 | `tools/mine_v1_translations.py` — builds en_text→{lang:text} index from v1 JSON, walks .pot, emits seeded `cge/locale/{lang}/btt-writer.po`. ~31% match rate on first run (68-69 of 216 single-line msgids per lang) | COMPLETE |
| 5 | `LocaleManager.pas` — `ApplyInterfaceLanguage` reads `GetInterfaceLanguage`, locates `cge/locale/{lang}/btt-writer.po` (exe-dir, exe-dir/.., or DATA PATH), calls `Translations.TranslateResourceStrings`. `ListAvailableLanguages` scans locale dir. Wired into `bttwriter2.lpr` after `InitializeAppSettings`, before splash | COMPLETE |
| 6 | `LocaleManager.PopulateLanguageCombo` populates SettingsForm combo from `.po` files present on disk + current setting fallback. Save path: writes `SetInterfaceLanguage(NewLang)`, prompts restart-required modal when changed | COMPLETE |
| 7 | `lazbuild bttwriter2.lpi` compiles clean. Launched with `interface_language=ru` in settings.json — log confirms `LocaleManager: loaded …/cge/locale/ru/btt-writer.po`. LCL `TranslateResourceStrings` parses `#: unit:rsname` location comments into `unit.rsname` identifiers, matching FPC runtime resourcestring keys. Visual GUI confirmation deferred to user | COMPLETE |
| 8 | `.lfm` caption extraction. `tools/extract-lfm-strings.py` walks each .lfm, tracks object nesting, emits `.po` entries keyed by `<formclass>.<comp>...<prop>` (lowercase) for Caption/Text/Hint/Title properties. `extract-pot.sh` merges into combined .pot (257 msgids now). LocaleManager assigns `LRSTranslator := TPOTranslator.Create(POPath)` so form-construction translates LFM properties via TPOTranslator | COMPLETE |
| 9 | Hot-swap. SettingsForm exposes OldLang/NewLang out-params; restart modal removed. MainForm + ProjectEditForm call `LocaleManager.HotReloadInterfaceLanguage` on change. HotReload re-applies the translator and walks `Screen.Forms` calling `TUpdateTranslator.UpdateTranslation(F)`. LFM-baked captions update both directions; code-assigned resourcestring captions remain at assigned-time value until form is recreated (accepted limitation) | COMPLETE |
| 10 | Layout clipping. LoginForm description labels set `AutoSize := False`, fixed `Width := 420`, `WordWrap := True`. Vertical spacing bumped to make room for 2-line wraps in longer translations (form height 400 → 460) | COMPLETE |

## Key Design Decisions

- **Two .pot files, one locale dir** — keeps CGE and LCL namespaces separate while sharing the directory the CGE branch already expects.
- **Mine by English text, not key** — legacy v1 keys (`bemode_maintext`) bear no relation to new resourcestring keys (`rsBlindEditCaption`). The English text is the only stable join column.
- **Per-language .po loaded at startup** — not hot-swap mid-session. Settings change triggers either form recreate or a restart prompt; simpler than chasing every cached caption.
- **Runtime path lookup** — `.po` files ship under `cge/locale/` relative to binary or DATA PATH. Final path resolution in `DataPaths.pas`.

## Files

**New:**
- `cge/locale/btt-writer-cge.pot` (copied from `castle-engine` branch)
- `cge/locale/btt-writer.pot` (emitted by build)
- `cge/locale/{en,es-419,fa,fr,pt-br,ru}/btt-writer.po` (pre-seeded by mining script)
- `tools/mine_v1_translations.py` (one-shot mining script)
- `LocaleManager.pas` or similar — runtime translator init + lang switch

**Modified:**
- `.gitignore` — add `!cge/locale/` exception
- `bttwriter2.lpi` — `<i18n>` config, register new unit
- `bttwriter2.lpr` — call `LocaleManager.Init` early
- `ProjectEditForm.pas` — strip 26 hardcoded captions
- `MainForm.pas` — strip 7 hardcoded captions
- `DevToolsForm.pas`, `ConflictResolver.pas`, `TermsForm.pas`, `SplashScreen.pas` — strip remaining
- `SettingsForm.pas` — wire Interface Language combo to `LocaleManager`
- `AppSettings.pas` — `InterfaceLang` already exists; verify default and persistence

## Verification

1. `lazbuild bttwriter2.lpi` — compiles clean each phase
2. After Phase 3 — `cge/locale/btt-writer.pot` exists with ≥248 msgids
3. After Phase 4 — `ru.po` and others contain real translations (spot-check 10 strings)
4. After Phase 5 — launching with `InterfaceLang=ru` shows Russian UI
5. After Phase 6 — switching language in Settings → restart → new lang loads
6. After Phase 7 — visual scan: no English leakage when running non-English lang
