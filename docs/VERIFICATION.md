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
