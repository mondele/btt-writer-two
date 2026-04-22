# UI Redesign Plan: Castle Game Engine

## Why CGE?

- **Pixel-perfect cross-platform rendering** — consistent look on Linux/Windows/macOS/Android without GTK2 quirks (coordinate limits, theme leakage, etc.)
- **True RTL mirroring** — direct control over layout geometry, no LCL gotchas
- **Android target** — CGE's primary strength over LCL; `castle-engine compile --target=android` works
- **Custom visual components** — chunk panels, verse balloons, pie charts are all easier to own
- **State-driven screen transitions** — screens change by mutating application state, not by imperatively showing/hiding forms; mirrors how the parallel Compose Android app works

## The Hard Problem: Text Editing

CGE has no `TMemo` or HTML renderer equivalent. This is the central tension:

| Current LCL widget | CGE equivalent | Effort |
|---|---|---|
| `TIpHtmlPanel` (source/trans display) | Custom `TCastleUserInterface` renderer | High |
| `TMemo` (USFM editing) | None — needs custom or native overlay | Very High |
| `TScrollBox` + chunk panels | `TCastleScrollView` + child UIs | Medium |
| `TPanel`, `TLabel`, `TButton` | `TCastleRectangleControl`, `TCastleLabel`, `TCastleButton` | Low |

**Recommended architecture: CGE shell + native text editing layer.** CGE owns navigation, layout, display rendering, and read modes. Native OS text input (platform edit control overlaid on the CGE window) handles USFM editing. This is how most game engines handle text input on mobile/desktop already.

---

## Phases

### Phase 0 — Architecture & Scaffolding (1–2 weeks)

- Add CGE as a package dependency via `fpcupdeluxe` or `castle-engine` submodule
- Create `CGEApp.pas` entry point: `TCastleWindow` standalone (not embedded in LCL)
- Port all non-UI units as-is: `DataPaths`, `ProjectManager`, `ResourceContainer`, `AppSettings`, `GiteaClient`, `AppLog` — zero changes needed
- Define `TCGEViewBase` base class with theme awareness and RTL layout flag

### Phase 1 — Widget Library (2–3 weeks)

Build a thin BTT-branded component layer over CGE primitives:

- `BTTTheme.pas` — maps `ThemePalette` colors to CGE `TCastleColor`
- `BTTButton.pas` — `TCastleButton` subclass with BTT visual style + RTL-aware icon placement
- `BTTScrollPanel.pas` — `TCastleScrollView` with styled scrollbar
- `BTTHeader.pas` — top bar component (reused across all views)
- `BTTSideRail.pas` — left (or right in RTL) navigation rail

### Phase 2 — Home Screen & Project List (1–2 weeks)

- `HomeView.pas` — `TCastleView` with project list
- Project rows: custom-drawn with pie chart via `TCastleShape` + `TCastleLabel`
- Sorting, empty state, "New Project" button
- Main menu popup (CGE `TCastleUserInterface` positioned panel)

### Phase 3 — Navigation & Dialog Infrastructure (1 week)

- View router: push/pop `TCastleView` stack
- Modal overlay system for dialogs (login, settings, import/export, source text chooser)
- File open/save dialogs: platform native dialogs via OS wrappers or CGE's own file picker

### Phase 4 — Source/Translation Display Renderer (3–4 weeks)

Replaces `TIpHtmlPanel` for read/display modes:

- `USFMRenderer.pas` — walks USFM tokens, lays out `TCastleLabel` spans in a `TCastleUserInterface`
- Verse marker "balloons" as draggable `TCastleButton`-like widgets
- Footnote popups
- RTL text direction via `TCastleLabel.TextDirection`
- Synced scrolling between source and translation columns

### Phase 5 — Chunk Editor (4–6 weeks, highest risk)

Two sub-options:

**Option A (recommended): Native text overlay**

- CGE window hosts a transparent region per editing chunk
- Overlay a platform text widget (GTK `GtkTextView` on Linux, `HWND` edit on Windows, `UITextView` on iOS/macOS) via CGE's native window handle
- `NativeTextEdit.pas` wraps the platform API; exposes `GetText`/`SetText`/`OnChange`
- Most portable approach that avoids reimplementing a text editor

**Option B: CGE custom editor**

- Full `TCastleUserInterface` multi-line editor with cursor, selection, keyboard handling
- ~3–6 months for a production-quality implementation
- Only warranted if Android support is a near-term priority (Option A is hard on Android)

### Phase 6 — Secondary Screens (2–3 weeks)

Port remaining dialogs to CGE views:

- Login/profile chooser
- Settings (4-tab equivalent using `TCastleScrollView` per tab)
- Import/export dialogs
- Conflict resolver (side-by-side ours/theirs display)

### Phase 7 — Android Target (2–4 weeks)

- `castle-engine compile --target=android --manifest=CastleEngineManifest.xml`
- Touch-friendly sizing (44dp min tap targets)
- On-screen keyboard integration with the native text overlay (Phase 5)
- `.apk` / `.aab` packaging

---

## Total Estimate

| Phase | Weeks |
|---|---|
| 0–1 (scaffolding + widgets) | 3–5 |
| 2–3 (home + nav) | 2–3 |
| 4 (display renderer) | 3–4 |
| 5 (chunk editor) | 4–6 |
| 6–7 (dialogs + Android) | 4–7 |
| **Total** | **~16–25 weeks** |

---

## Recommended First Step

Build a **proof-of-concept spike** (1 week): get CGE compiling alongside the existing codebase, render a single chunk panel with verse markers in a `TCastleWindow`, and prove the native text overlay approach works on Linux. This validates Phase 5's feasibility and de-risks the largest unknown before the full redesign begins.
