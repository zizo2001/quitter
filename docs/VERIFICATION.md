# Quitter — Verification Log

One entry per phase gate (PLAN §9). Evidence = command output, `pgrep`, window-list dumps
(`CGWindowListCopyWindowInfo` filtered to owner `Quitter`), and screenshots in `docs/evidence/`.

## Phase log

- **Phase 0 — scaffold.** `make run`: `xmark.circle` in menu bar; click → panel window appears
  (`layer=101 340x196`), Esc → window gone, click again → open, click → gone; glass renders over
  Finder content (`evidence/phase0-panel.png`); `make test` → "Test run with 0 tests in 0 suites
  passed"; `make app` → `codesign --verify --deep --strict` OK, `Signature=adhoc`, bundle launched
  (`pgrep -lx Quitter` → `14977 Quitter` from `build/Quitter.app`). Deviation: tools-version 6.0 →
  6.2 (`'v26' was introduced in PackageDescription 6.2`).
- **Phase 1 — list.** `make test` → 9 tests / 2 suites passed (AppFilter + ProtectedStore incl.
  corrupt-JSON move-aside). `lsappinfo list` Foreground apps = Claude, Dia, Discord, Finder,
  NordVPN, Spotify, System Settings, TV, Wispr Flow; panel listed exactly those minus Finder
  (`evidence/phase1-list.png`). `open -g -a TextEdit` with panel open → TextEdit row appeared live,
  panel grew 436→480 pt with top edge fixed (`phase1-textedit-added.png`); typed "text" → only
  TextEdit (`phase1-search-text.png`); `osascript -e 'quit app "TextEdit"'` → `pgrep` empty and row
  gone, "No apps match “text”" (`phase1-textedit-removed.png`).
- **Phase 2 — quit + escalation.** `make test` → 16 tests / 3 suites passed (7 QuitCoordinator
  tests with fake `Terminating` + fake clock). `open -a TextEdit; open -a Calculator`, ticked both
  (`evidence/phase2-selected.png`: "2 selected", red "Quit 2"), clicked Quit → first `pgrep` poll
  at +500 ms: `TextEdit=[] Calculator=[]`; panel auto-closed. Then TextEdit "Untitled — Edited":
  search "textedit" → Space → Return → save dialog appeared, `pgrep` still 18362, row went
  straight to **Force Quit** (`phase2-b-requested.png`; `terminate()` returned false, the
  immediate-stuck path), icon `xmark.circle.fill` (`phase2-b-icon.png`). Esc×2 closed the panel;
  reopening showed the same Force Quit row (`phase2-b-reopened.png`); clicking it → `pgrep -x
  TextEdit` empty, panel closed, icon back to outline (`phase2-b-icon-after.png`).
- **Phase 3 — usage.** Plain `import Darwin` resolved `proc_pid_rusage`/`proc_listchildpids` (no
  `CLibProc` shim). `make test` → 22 tests / 4 suites passed. Chrome (throwaway profile, 8-process
  tree: main + 7 helpers per `ps`): panel **647.6 MB**; Activity Monitor Memory column for those
  pids 263.1+102.8+99.8+55.3+51.7+28.7+25.4+20.8 = **647.6 MB** (0 % off;
  `evidence/phase3-usage-2.png`). Safari panel 47.4 MB vs `top` 47 MiB (WebContent processes are
  XPC children of launchd, as in AM). `yes > /dev/null` in Terminal → Terminal row **99–100 %**.
  Sort by CPU, captures at t=0 and t=8 s: identical order while values changed (Safari 3 %→0 %
  stayed above Activity Monitor 3 %) (`phase3-cpu-t0.png`, `phase3-cpu-t8.png`).
  Fixes found here: (1) outside-click monitor closed the panel on clicks in our own menu window →
  now ignores non-normal-level windows; (2) the "Sort by" submenu never opened/tracked from the
  non-activating panel while another app is active → sort options are an inline menu section
  (`phase3-menu.png`); (3) Swift 6.3 compiler crash (`SmallVector unable to grow`) on
  `Binding(set: model.setSortOrder)` → explicit closure.
