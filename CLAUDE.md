# Quitter — macOS menu bar multi-quit app

Native macOS utility: menu bar icon → Liquid Glass panel listing running Dock apps with checkboxes
→ one **Quit** button quits all selected. Auto-escalates to a per-row **Force Quit** after a
timeout. Quit Groups, global hotkey, search, protected apps, System-Settings-style preferences.

**The full specification is `PLAN.md`. Read it completely before writing code.** Every design
decision is already made there; do not reopen them. Execute its phases (§9) in order and pass each
gate with evidence before moving on.

## Stack
- Swift 6 language mode, SwiftUI views hosted in AppKit (`NSHostingView`), macOS 26.0 minimum
- SwiftPM executable target, **no `.xcodeproj`**. `scripts/build-app.sh` assembles the `.app`
- Only dependency: `sindresorhus/KeyboardShortcuts`. Add nothing else.
- Process stats via libproc (`proc_pid_rusage`, `proc_listchildpids`)
- Tests: Swift Testing (`import Testing`), pure logic only

## Commands
```
make run       # swift run Quitter — dev loop, no bundle (login-item toggle disabled here)
make test      # swift test
make app       # release build → build/Quitter.app (ad-hoc signed)
make install   # make app + replace /Applications/Quitter.app + relaunch
make icon      # regenerate Resources/AppIcon.icns
```

## Non-negotiables
- `NSStatusItem` + custom `NSPanel`, never `MenuBarExtra` (see PLAN §2 for why)
- Pure AppKit entry (`AppDelegate` is `@main`), no SwiftUI `App`/`Settings` scene
- `@main` file is never named `main.swift`
- No force unwraps, no `try!`, no private APIs
- `NSRunningApplication` / `NSImage` never cross an actor boundary; sampling gets `[pid_t]` only
- Quitter and Finder are protected by default; Quitter itself can never be un-protected
- Never force-quit without an explicit click on that row's Force Quit button

## Verification rules
- A phase is done only when its gate in PLAN §9 passed with real evidence: command output,
  `pgrep -x <App>`, or a screenshot. Writing "verified" without evidence is a failure.
- Use `open -a TextEdit`, `open -a Calculator`, `osascript` and `pgrep` to drive quit tests.
- Compare memory numbers against Activity Monitor's Memory column, not against guesses.
- Append one line per phase to `docs/VERIFICATION.md` as you go; finish it in phase 8.
- Commit after each passed gate: imperative mood, author `Aziz Ali <aziz.alfta@gmail.com>`.
  Do not push.

## Known gotchas (from planning, verify when hit)
- `LSUIElement` apps open windows behind others: call `NSApp.activate()` before showing Settings
- `MenuBarExtra`-style panels close when another app's save sheet takes focus; our
  `QuitCoordinator` is long-lived so reopening the panel shows stuck rows again
- `ri_user_time`/`ri_system_time` are Mach absolute units → convert with `mach_timebase_info`
- `SMAppService` only works from a real bundle, never from `swift run`
- If `.glassEffect` renders black inside the transparent panel, use the `.regularMaterial`
  fallback in PLAN §7 and note it in `docs/VERIFICATION.md`
- If `proc_pid_rusage` is not visible via `import Darwin`, add the `CLibProc` shim target (PLAN §4)
