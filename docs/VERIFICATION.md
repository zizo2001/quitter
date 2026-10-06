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
