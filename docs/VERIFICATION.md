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
- **Phase 4 — Settings.** Gear and ⌘, both open "Quitter Settings" (680×460) in front: with
  Calculator verifiably frontmost (`lsappinfo front`), ⌘, from the panel → `lsappinfo front` =
  Quitter, window key (`evidence/phase4-cmd-comma.png`). Cooperative `NSApp.activate()` was
  refused there (logged `isActive=false`), so the controller uses `activate(ignoringOtherApps:)`.
  Toggled Show background apps + Ask before quitting → `defaults read` showed both = 1; after
  relaunch the switches were still on and the panel listed accessory apps. Protected › + › Add
  Running App… › Calculator → `protected.json` gained `com.apple.calculator`; panel search "calc"
  → "No apps match “calc”" while `pgrep` showed Calculator 22017 running
  (`phase4-calc-hidden.png`); removed it again with −. After `make install`, Launch at Login
  toggle → on (`phase4-login-on.png`) and System Settings › General › Login Items › Open at Login
  lists "Quitter — Application".
  Test-harness note: computer-use only indexes regular-policy apps, so a DEBUG-only
  `QUITTER_REGULAR_POLICY=1` env override was added once to let it grant `com.azizali.quitter`.
- **Phase 5 — groups.** `make test` → 26 tests / 5 suites passed (4 GroupStore tests: temp-dir
  round trip, upsert keeps app order, remove/move persist, corrupt file moved aside). Settings ›
  Groups › + → editor (Save disabled while name empty) → name "Focus", symbol moon, Add Apps › Add
  from running… → Safari, Notes → Save. `groups.json`: `{"bundleIDs":["com.apple.Safari",
  "com.apple.Notes"],"name":"Focus","symbol":"moon",…}`. Relaunched Quitter → chip
  "Focus · 2" (`evidence/phase5-chip.png`); click → chip tinted, Notes + Safari ticked, "Quit 2"
  (`phase5-chip-selected.png`); Quit → first poll at +500 ms `Safari=[] Notes=[]`.
- **Phase 6 — hotkey.** Real failure on KeyboardShortcuts 2.4.0 (plan's `from: "2.0.0"`): clicking
  the Recorder showed a text caret and "Record Shortcut" never switched to "Press Shortcut"; ⌃⌥Q
  was not captured and a typed "x" landed as text. Upstream 3.1.0 (2026-09-11, "Improve macOS 27
  compatibility": AppKit on macOS 26+ ends/restarts field editing, which ended recording; 3.0.x
  also fixes a "release build crash with the Swift 6.3 compiler") → dependency now
  `from: "3.1.0"`; no API used by Quitter changed. With 3.1.0: Recorder showed "Press Shortcut",
  ⌃⌥Q recorded (`defaults`: `{"carbonKeyCode":12,"carbonModifiers":6144}`). With Calculator
  frontmost: ⌃⌥Q → panel open, Calculator still frontmost, typed "spot" went to the search field
  (`evidence/phase6-hotkey-open.png`); ⌃⌥Q again → panel gone. Repeated 3× on a fresh process
  (handler log: 2 keyUps per cycle). Also with Settings key: ⌃⌥Q opened, then closed, the panel.
  One earlier miss happened right after the recorder had wrongly captured ⌘W with stuck
  modifiers (6912); not reproducible.
- **Phase 7 — keyboard + polish.** Hotkey changed at Aziz's request to **Caps Lock + Q**: Hyperkey
  maps Caps Lock to ⌃⌥⇧⌘ (`hyperFlags = 0x1E0000`), so the stored shortcut is ⌃⌥⇧⌘Q
  (`{"carbonKeyCode":12,"carbonModifiers":6912}`); synthetic ⌃⌥⇧⌘ keystrokes never reached the
  Recorder, so the value was written to `com.azizali.quitter` defaults directly; ⌃⌥⇧⌘Q then
  opened and closed the panel and the old ⌃⌥Q did nothing. Full keyboard run with Calculator
  frontmost: ⌃⌥⇧⌘Q → "calc" → Space (cursor auto-highlights the first match) → "1 selected"
  (`evidence/phase7-keyboard-ticked.png`) → Return → `pgrep -x Calculator` empty at +500 ms.
  Right-click menu: Open Quitter / Settings… ⌘, / Launch at Login ✓ / Quit Quitter ⌘Q
  (`phase7-rightclick.png`); "Settings…" opened Settings. About pane shows icon, "Quitter 1.0.0",
  tagline, "Built by Aziz Ali", Reveal Project Folder. Light/dark captures via the DEBUG-only
  `QUITTER_APPEARANCE` override, so the system appearance setting stays untouched
  (`phase7-light.png`, `phase7-dark.png`). Ask before quitting → in-panel "Quit 1 app?
  Calculator" (`phase7-confirm.png`), Return confirmed → Calculator gone. "Save selection as
  Group…" with Notes + Safari selected → Settings › Groups editor prefilled with both
  (`phase7-save-selection.png`); Esc cancelled (still 1 group). Fix: ⌘W did nothing in Settings
  (no main menu in an LSUIElement app) → the window now handles ⌘W itself; verified closed.
