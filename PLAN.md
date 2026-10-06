# Brief for Opus 5.5 — Build Quitter

## 1. What Quitter is

A menu bar utility. Click the icon (or press a global hotkey) and a Liquid Glass panel drops down
listing every Dock app that is running, each with its icon, name, memory and CPU use, and a
checkbox. Tick several, press **Quit**, and they all receive a normal quit. Apps that refuse to die
within a timeout get a per-row **Force Quit** button. Named Quit Groups let one click select a
preset set of apps. A System-Settings-style window holds all preferences.

Target: macOS 26.0 minimum (built and used on macOS 27). No sandbox, ad-hoc signed, local install
to `/Applications`. Not for distribution.

## 2. Architecture decisions (fixed, do not revisit)

| Decision | Choice | Why |
|---|---|---|
| Build system | **SwiftPM executable target + `scripts/build-app.sh`** that assembles `build/Quitter.app` | No `.xcodeproj` to hand-write; `swift build` works headless from Claude Code. Xcode can still open `Package.swift`. |
| App lifecycle | **Pure AppKit entry** (`NSApplication` + `AppDelegate`), SwiftUI for all views via `NSHostingView` | No SwiftUI `App`/`Settings` scene: we need programmatic open of the panel and of Settings, which the scene APIs do not expose reliably from an `LSUIElement` app. |
| Menu bar | **`NSStatusItem` + custom non-activating `NSPanel`**, not `MenuBarExtra` | `MenuBarExtra` cannot be opened from a hotkey and closes when another app's save sheet takes focus, which breaks the force-quit escalation UI. |
| Settings | Own `NSWindow` hosting a SwiftUI **sidebar-style** settings view (System Settings look) | Deterministic open/close; looks native on 26+. |
| Global hotkey | SwiftPM dependency **`sindresorhus/KeyboardShortcuts`** (`from: "2.0.0"`) | Mature; ships the recorder control for the Settings UI. |
| Process stats | `proc_pid_rusage` (`RUSAGE_INFO_V4`) + `proc_listchildpids` from libproc | Same numbers Activity Monitor shows (`ri_phys_footprint`). Needs no privileges for same-user processes. |
| Persistence | `@AppStorage`/`UserDefaults` for scalar settings; JSON files in `~/Library/Application Support/Quitter/` for groups and protected list | Simple, inspectable, no Core Data. |
| Concurrency | Swift 6 language mode. All AppKit/UI classes `@MainActor`. Sampling runs off-main with `pid_t` values only (Sendable). `NSRunningApplication` never crosses an actor boundary. | Strict concurrency catches real bugs here; the boundaries are small. |
| Login item | `SMAppService.mainApp` | Modern API, no helper bundle. Only works from the built bundle, not `swift run`. |
| Tests | Swift Testing (`import Testing`) for pure logic behind protocols | Fast; UI verified manually per gate. |

## 3. Project layout

```
quitter/
  CLAUDE.md
  PLAN.md
  Package.swift
  Makefile                       # build, run, test, app, install, clean
  scripts/
    build-app.sh                 # swift build -c release → build/Quitter.app (+ --install)
    make-icon.swift              # renders AppIcon.icns (run with `swift scripts/make-icon.swift`)
  Resources/
    Info.plist
    AppIcon.icns                 # generated, committed
  Sources/Quitter/
    App/
      AppDelegate.swift          # @main. Wires everything. setActivationPolicy(.accessory)
      Dependencies.swift         # single composition root: creates stores, monitor, coordinator
    StatusBar/
      StatusBarController.swift  # NSStatusItem, icon state, right-click menu, panel toggle
      PanelWindow.swift          # NSPanel subclass (non-activating, key-capable), positioning
    Models/
      RunningApp.swift           # value type shown in the list
      QuitGroup.swift            # Codable preset
      QuitState.swift            # idle / requested(Date) / stuck / terminated
      SortOrder.swift            # name / memory / cpu / launched
    Services/
      AppMonitor.swift           # @Observable; mirrors NSWorkspace.runningApplications
      AppFilter.swift            # pure: policy + protected + query → [RunningApp]
      ProcessStats.swift         # libproc wrappers: footprint, cpu time, children
      UsageSampler.swift         # timer while panel visible; publishes pid → Usage
      QuitCoordinator.swift      # terminate, escalation timers, Terminating protocol
      GroupStore.swift           # JSON load/save, CRUD
      ProtectedStore.swift       # JSON load/save; always contains self + default Finder
      LoginItem.swift            # SMAppService wrapper
      Hotkeys.swift              # KeyboardShortcuts.Name definitions + bindings
      Settings.swift             # typed keys + defaults (UserDefaults)
    Design/
      Tokens.swift               # spacing, radii, sizes, fonts
      Glass.swift                # panelBackground() modifier with fallback
    Views/Panel/
      PanelView.swift            # root; owns keyboard handling + focus
      SearchField.swift
      GroupChipsRow.swift
      AppRow.swift
      PanelFooter.swift
      EmptyState.swift
    Views/Settings/
      SettingsWindowController.swift
      SettingsView.swift         # NavigationSplitView sidebar + detail
      GeneralPane.swift
      GroupsPane.swift
      GroupEditor.swift
      ProtectedPane.swift
      ShortcutsPane.swift
      AboutPane.swift
  Tests/QuitterTests/
    AppFilterTests.swift
    QuitCoordinatorTests.swift   # fake Terminating + fake clock
    GroupStoreTests.swift        # temp dir round-trip
    ProcessStatsTests.swift      # cpu % math from deltas
  docs/
    VERIFICATION.md              # written by Opus at the end
```

## 4. Package, bundle, build

### Package.swift

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Quitter",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "Quitter",
            dependencies: ["KeyboardShortcuts"],
            path: "Sources/Quitter",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "QuitterTests",
            dependencies: ["Quitter"],
            path: "Tests/QuitterTests"
        ),
    ]
)
```

Gotchas:
- The `@main` file must **not** be named `main.swift`, or SwiftPM reports "'main' attribute cannot
  be used in a module that contains top-level code".
- If `proc_pid_rusage` / `proc_listchildpids` do not resolve under `import Darwin`, add a system
  library target `CLibProc` with a `shim.h` that `#include <libproc.h>` and a `module.modulemap`,
  and depend on it from `Quitter`. Try plain `import Darwin` first.
- Test target importing an executable target works on SwiftPM ≥ 5.5 with `@testable import Quitter`.

### Resources/Info.plist (keys that matter)

```
CFBundleIdentifier        com.azizali.quitter
CFBundleName              Quitter
CFBundleDisplayName       Quitter
CFBundleExecutable        Quitter
CFBundlePackageType       APPL
CFBundleShortVersionString 1.0.0
CFBundleVersion           1
CFBundleIconFile          AppIcon
LSMinimumSystemVersion    26.0
LSUIElement               true          ← no Dock icon, no app menu
NSHighResolutionCapable   true
NSHumanReadableCopyright  © 2026 Aziz Ali
```

### scripts/build-app.sh

1. `swift build -c release --product Quitter`
2. `rm -rf build/Quitter.app` then create `build/Quitter.app/Contents/{MacOS,Resources}`
3. Copy binary, `Resources/Info.plist`, `Resources/AppIcon.icns`
4. Copy the KeyboardShortcuts resource bundle if SwiftPM produced one
   (`.build/release/KeyboardShortcuts_KeyboardShortcuts.bundle` → `Contents/Resources/`)
5. `codesign --force --deep --sign - build/Quitter.app`
6. With `--install`: `pkill -x Quitter || true`, `rm -rf /Applications/Quitter.app`,
   `cp -R build/Quitter.app /Applications/`, `open /Applications/Quitter.app`

### Makefile targets

`build` (debug), `run` (`swift run Quitter`; AppDelegate calls `setActivationPolicy(.accessory)` so
no Dock icon even without a bundle), `test`, `app` (build-app.sh), `install` (build-app.sh
--install), `icon` (regenerate icns), `clean`.

### scripts/make-icon.swift

Standalone script: draws a 1024×1024 macOS-style rounded squircle with a vertical gradient
(top `#FF6B6B` → bottom `#C0392B`, red = quit), centred white SF Symbol `xmark` at weight bold,
size ~560pt. Writes PNGs at 16/32/64/128/256/512/1024 (+@2x pairs) into a temp `.iconset`, runs
`iconutil -c icns`, outputs `Resources/AppIcon.icns`. Uses `NSImage`, `NSBezierPath`,
`NSImage(systemSymbolName:)`. Commit the generated icns.

## 5. Data model

```swift
struct RunningApp: Identifiable, Hashable {
    let id: pid_t
    let bundleID: String?
    let name: String
    let icon: NSImage              // NSRunningApplication.icon ?? generic app icon
    let launchDate: Date?
    let policy: NSApplication.ActivationPolicy
    var usage: Usage?              // nil until first sample
}

struct Usage: Hashable, Sendable {
    let memoryBytes: UInt64        // phys footprint, self + all descendant processes
    let cpuPercent: Double         // 0...n*100, Activity-Monitor style
}

enum QuitState: Equatable {
    case idle
    case requested(at: Date)       // terminate() sent, waiting
    case stuck                     // timeout passed, or terminate() returned false
    case terminated
}

struct QuitGroup: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var symbol: String             // SF Symbol name, default "square.stack"
    var bundleIDs: [String]        // order preserved
}

struct ProtectedApp: Codable, Hashable {
    let bundleID: String
    let name: String
}

enum SortOrder: String, CaseIterable { case name, memory, cpu, launched }
```

Settings keys (`Settings.swift`, all `UserDefaults`, with defaults):

| Key | Type | Default |
|---|---|---|
| `showBackgroundApps` | Bool | false |
| `sortOrder` | SortOrder | `.name` |
| `forceQuitDelaySeconds` | Int (2…30) | 5 |
| `closePanelAfterQuit` | Bool | true |
| `confirmBeforeQuit` | Bool | false |
| `showUsage` | Bool | true |
| `launchAtLogin` | derived from `SMAppService.mainApp.status`, not stored | — |

## 6. Services

### AppMonitor (`@MainActor @Observable`)

- Source of truth: `NSWorkspace.shared.runningApplications`.
- Observe with KVO publisher on `runningApplications` **and** `NSWorkspace.shared.notificationCenter`
  `didLaunchApplicationNotification` / `didTerminateApplicationNotification`. Rebuild `apps:
  [RunningApp]` on every change. Keep `NSRunningApplication` objects in a private `[pid_t:
  NSRunningApplication]` dictionary for `QuitCoordinator` to use; never put them in the view model.
- Always exclude: own pid (`ProcessInfo.processInfo.processIdentifier`), `activationPolicy ==
  .prohibited`, apps with `isTerminated == true`.
- Policy filter: `.regular` always; `.accessory` only when `showBackgroundApps` is on.

### AppFilter (pure, tested)

`static func apply(apps: [RunningApp], protected: Set<String>, query: String, sort: SortOrder) ->
[RunningApp]`. Protected bundle IDs are removed entirely (they never appear). Query is
case/diacritic-insensitive prefix-or-contains on name. Sort: name (localized, case-insensitive),
memory desc, cpu desc, launched desc (newest first); nil usage sorts last.

### ProcessStats (libproc)

```swift
enum ProcessStats {
    static func footprint(pid: pid_t) -> UInt64?         // rusage_info_v4.ri_phys_footprint
    static func cpuTimeNanos(pid: pid_t) -> UInt64?      // ri_user_time + ri_system_time, converted
    static func descendants(of pid: pid_t) -> [pid_t]    // proc_listchildpids, recursive, depth ≤ 6
}
```

- `ri_user_time`/`ri_system_time` are in **Mach absolute time units**. Convert with
  `mach_timebase_info` (`value * numer / denom` → nanoseconds).
- CPU % for one sample interval: `(Δcpu_ns_total_including_descendants / Δwall_ns) * 100`.
  Clamp at 0; do not cap at 100 (multi-core apps exceed it, same as Activity Monitor).
- Memory shown = footprint of pid + all descendants (Chrome/Electron helpers). Row tooltip:
  "Includes helper processes".
- First sample has no delta → `cpuPercent = 0`, show "—" until the second sample.

### UsageSampler

- Started when the panel becomes visible, stopped when hidden. Interval 2 s. Runs sampling in a
  detached task over a `[pid_t]` snapshot, returns `[pid_t: Usage]`, applies on main actor into
  `AppMonitor.apps[*].usage`.
- Sorting by memory/cpu re-sorts **only on panel open and membership change**, not on each sample,
  so rows do not jump under the cursor.

### QuitCoordinator (`@MainActor @Observable`)

```swift
protocol Terminating { func terminate(pid: pid_t) -> Bool; func forceTerminate(pid: pid_t) -> Bool; func isRunning(pid: pid_t) -> Bool }
```

- `states: [pid_t: QuitState]`, `pendingCount` (requested + stuck).
- `quit(pids:)`: for each pid, `terminate` → `.requested(now)`; if `terminate` returned `false`
  → `.stuck` immediately.
- A 0.5 s poll (while `pendingCount > 0`) checks `isRunning`; false → `.terminated`, remove after
  the row's exit animation (0.3 s). If `now - requestedAt ≥ forceQuitDelay` → `.stuck`.
- `forceQuit(pid:)`: `forceTerminate` → stays `.requested` until the poll sees it gone.
- The coordinator is **long-lived** (owned by `Dependencies`), so state survives the panel closing
  when another app's save sheet steals focus. Reopening the panel shows the same rows in their
  current state.
- `StatusBarController` observes `pendingCount`: icon is `xmark.circle` when 0, `xmark.circle.fill`
  when > 0.

### GroupStore / ProtectedStore

- Files: `groups.json`, `protected.json` under `FileManager.urls(for: .applicationSupportDirectory)/Quitter/`.
  Create directory on first write. Atomic writes. Load on init; on decode failure, rename the bad
  file to `*.corrupt-<timestamp>` and start empty (never crash on bad JSON).
- `ProtectedStore.bundleIDs` always includes `com.azizali.quitter` (not removable in UI, shown
  greyed) and seeds `com.apple.finder` on first launch (removable).

### LoginItem

`var isEnabled: Bool { SMAppService.mainApp.status == .enabled }`, `set(_:)` calls
`register()`/`unregister()` and surfaces thrown errors as a string for the UI. When running via
`swift run` (no bundle) the toggle is disabled with help text "Available when installed".

### Hotkeys

`extension KeyboardShortcuts.Name { static let togglePanel = Self("togglePanel") }` — no default
shortcut. `onKeyUp(for: .togglePanel)` → `StatusBarController.togglePanel()`.
Stretch (phase 9 only): per-group `Name("group-<uuid>")` that quits the group instantly.

## 7. Panel — behaviour and design

### Window (`PanelWindow: NSPanel`)

- `styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView]`, `level: .popUpMenu`,
  `isOpaque = false`, `backgroundColor = .clear`, `hasShadow = true`, `isMovable = false`,
  `hidesOnDeactivate = false`, `collectionBehavior: [.canJoinAllSpaces, .fullScreenAuxiliary,
  .stationary]`. Override `canBecomeKey = true` so the search field accepts typing without
  activating Quitter.
- Content: `NSHostingView(rootView: PanelView(...))`. Width **340 pt**. Height = intrinsic content,
  capped at **540 pt** (list scrolls beyond that).
- Position: centred horizontally under the status item button, 6 pt below the menu bar, on the
  button's screen. If the status button is hidden (notch / overflow) or its window is nil, fall back
  to top-right of `NSScreen.main` with 12 pt margins.
- Open: `orderFrontRegardless()` + `makeKey()`, then focus the search field. Close on: outside
  click (global + local `NSEvent` monitors for `.leftMouseDown`/`.rightMouseDown`), Esc, hotkey,
  status item click, `resignKey` (via `NSWindow.didResignKeyNotification`). Remove monitors on close.
- Appearance: follows system (light/dark) automatically.

### Layout (top → bottom)

1. **Header** (height 36): "Quitter" `.headline` left; right: `gearshape` icon button (opens
   Settings) and an `ellipsis.circle` menu: Sort by (Name/Memory/CPU/Launched), "Save selection as
   Group…", "Select All", "Select None".
2. **Search field**: rounded, `magnifyingglass` leading icon, placeholder "Search apps", clear
   button when non-empty. Autofocused on open. Typing while the list has focus redirects to it.
3. **Group chips row** (only if ≥ 1 group): horizontal scroll of capsules: symbol + name + running
   count badge ("Focus · 3"). Click selects the group's running members (adds to selection); click
   again deselects them. 0 running members → chip dimmed and disabled. Chip tinted when all its
   running members are selected.
4. **App list** (`ScrollView` + `LazyVStack`, rows 44 pt, 8 pt horizontal inset):
   - `[checkbox] [icon 28×28] [name .body] / [subtitle .caption secondary: "1.2 GB · 3 %"]`
   - Usage hidden if `showUsage` off. Memory formatted with `ByteCountFormatter` (`.memory` style);
     CPU rounded to integer %, "—" before first delta.
   - States: `.requested` → checkbox disabled, row 50 % opacity, small `ProgressView` trailing;
     `.stuck` → trailing red `.borderedProminent` small button **Force Quit**; `.terminated` →
     row slides out (`.transition(.move(edge: .trailing).combined(with: .opacity))`).
   - Row click anywhere toggles selection (except on the Force Quit button).
   - Highlighted row (keyboard cursor) has a subtle `quaternary` fill, 10 pt radius.
5. **Footer** (height 48, hairline separator above): left "n selected" `.caption` secondary; right
   **Quit** button `.glassProminent` (fallback `.borderedProminent`), tint red, title "Quit" when
   0 selected (disabled) else "Quit 3". If `confirmBeforeQuit` → `NSAlert`-style confirmation sheet
   inside the panel listing the names.
6. **Empty state** (replaces list): `checkmark.circle` 36 pt secondary + "Nothing to quit" +
   caption "No Dock apps are running." When a search has no hits: "No apps match “xyz”".

### Keyboard

| Key | Action |
|---|---|
| ↑ / ↓ | move cursor (wraps) |
| Space | toggle checkbox at cursor |
| ⌘A | select all visible |
| ⌘⇧A | select none |
| Return | Quit selected (no-op if 0) |
| Esc | clear search if non-empty, else close panel |
| ⌘, | open Settings |
| any printable | goes to search field |

### Glass / design tokens

- Panel background: `.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 22,
  style: .continuous))` on the root `VStack` (macOS 26 API). Fallback if it renders black or
  flickers in the transparent panel: `.background(.regularMaterial, in: same shape)` with
  `.overlay(shape.strokeBorder(.white.opacity(0.08)))`.
- Buttons: `.glass` for secondary, `.glassProminent` for Quit. Chips:
  `.glassEffect(.regular.interactive(), in: .capsule)`.
- Tokens: spacing 4/8/12/16/20; radii 10 (rows) / 14 (field) / 22 (panel); icons 28; row 44;
  panel width 340; fonts `.headline`, `.body`, `.caption`; all colors semantic (`.primary`,
  `.secondary`, `.quaternary`, `Color.red` for destructive).
- Animations: `.snappy` for selection, `.smooth(duration: 0.3)` for row exit, panel open/close
  with 0.15 s fade + 4 pt slide (implemented by animating `alphaValue` and frame on the NSPanel).
- No custom fonts, no custom colours beyond the red tint, no emoji.

### After pressing Quit

1. Selection is cleared, rows move to `.requested`.
2. Rows disappear as apps die. When `pendingCount` reaches 0 and `closePanelAfterQuit` is on,
   the panel closes after 0.6 s.
3. If any row becomes `.stuck`, the panel stays open and the icon becomes `xmark.circle.fill`.
   If the panel was closed by focus loss (save sheet), reopening shows the stuck rows with their
   Force Quit buttons.

### Status item

- Icon: SF Symbol `xmark.circle` (template image, `isTemplate = true`, point size 15, weight
  medium). `xmark.circle.fill` while quits are pending. Tooltip "Quitter".
- Left click: toggle panel. Right click: `NSMenu` — "Open Quitter", "Settings…" (⌘,), separator,
  "Launch at Login" (checkmark state), separator, "Quit Quitter".

## 8. Settings window

- `SettingsWindowController`: single `NSWindow`, `styleMask: [.titled, .closable,
  .fullSizeContentView]`, `titlebarAppearsTransparent = true`, size 680×460, min 600×400, title
  "Quitter Settings", centred on first open, remembers frame (`setFrameAutosaveName`). Opening
  calls `NSApp.activate()` + `makeKeyAndOrderFront` so it is not hidden behind other apps
  (`LSUIElement` apps otherwise open windows in the background). Closing the window does not quit
  the app.
- `SettingsView`: `NavigationSplitView` — sidebar `List` with selection, rows = SF symbol in a
  20×20 rounded-square tinted background + label, like System Settings. Detail = `Form` with
  `.formStyle(.grouped)`.

| Pane | Symbol / tint | Contents |
|---|---|---|
| General | `gearshape` / gray | Launch at Login toggle (+ error text) · Show background apps · Sort by picker · Force Quit after `Stepper` 2–30 s · Close panel after quitting · Ask before quitting · Show memory and CPU |
| Groups | `square.stack` / blue | List of groups (symbol, name, "n apps"); `+` / `−`; double-click or `Edit` opens `GroupEditor` sheet; drag to reorder |
| Protected | `lock.shield` / green | List of protected apps with icons; `+` opens `NSOpenPanel` (`allowedContentTypes: [.application]`, starts in /Applications) or "Add running app…" popover; `−` removes. Quitter row greyed, not removable. Footer text: "Protected apps never appear in the list." |
| Shortcuts | `keyboard` / purple | `KeyboardShortcuts.Recorder("Open Quitter:", name: .togglePanel)`. Stretch: a recorder per group. |
| About | `info.circle` / gray | App icon, "Quitter 1.0.0", "Multi-quit for the menu bar", "Built by Aziz Ali", button "Reveal Project Folder" |

- `GroupEditor` sheet: name field, symbol picker (fixed set of 12 SF symbols), app list with
  icons (resolve via `NSWorkspace.shared.urlForApplication(withBundleIdentifier:)` for icon and
  current name; show "Not installed" if nil), "Add from running…" popover (checkbox list of current
  Dock apps) and "Add from disk…" (`NSOpenPanel`). Save / Cancel. Empty name disables Save.

## 9. Phases and gates (execute in order, commit after each gate)

Each gate must be demonstrated with evidence in the session (command output, `pgrep`, or a
screenshot via the computer-use tools). Write a one-line summary per phase into
`docs/VERIFICATION.md` as you go.

| # | Phase | Gate |
|---|---|---|
| 0 | `git init`, `.gitignore` (`.build/`, `build/`, `.DS_Store`, `*.xcodeproj`), scaffold `Package.swift`, `Makefile`, `scripts/`, `Resources/`, `AppDelegate` with status item + empty `PanelWindow`, icon generated | `make run` shows `xmark.circle` in the menu bar; click opens/closes an empty glass panel; Esc closes; `make test` runs 0 tests green; `make app` produces a signed `build/Quitter.app` that launches |
| 1 | `AppMonitor`, `AppFilter` (+tests), `ProtectedStore` defaults, list rows with icons, search, empty state | Panel list equals the Cmd-Tab switcher minus Finder and Quitter; launching/quitting TextEdit externally adds/removes its row live; search "text" narrows to TextEdit |
| 2 | Selection, footer, `QuitCoordinator` (+tests with fake `Terminating`), escalation, Force Quit button, pending icon state | `open -a TextEdit; open -a Calculator`, tick both, Quit → both gone within 2 s (`pgrep -x TextEdit` empty). Then TextEdit with an unsaved doc: Quit → save sheet appears, panel may close; after 5 s reopen → row shows **Force Quit**; click → `pgrep` empty |
| 3 | `ProcessStats`, `UsageSampler` (+tests), subtitle formatting, sort orders | Memory for Safari/Chrome within ±15 % of Activity Monitor's Memory column (sum of helpers); CPU of a busy app (`yes > /dev/null` from Terminal) shows Terminal ≥ 90 %; rows do not reorder during sampling |
| 4 | Settings window, General pane, Protected pane, `LoginItem` | ⌘, and the gear open Settings in front; toggles persist across relaunch; adding Calculator to Protected hides it from the panel; Launch at Login shows in System Settings › General › Login Items after `make install` |
| 5 | `GroupStore` (+tests), Groups pane, `GroupEditor`, chips row, "Save selection as Group…" | Create group "Focus" = Safari + Notes; chip shows "Focus · 2" when both run; click selects both; Quit kills both; group survives relaunch; `groups.json` is readable |
| 6 | `Hotkeys`, Shortcuts pane | Record ⌃⌥Q; from any app the hotkey opens the panel with search focused; pressing again closes it |
| 7 | Keyboard flow, animations, right-click menu, About, polish pass against §7 and §8 | Full keyboard run: hotkey → type "calc" → Space → Return → Calculator quits without the mouse. Light and dark screenshots look like §7 |
| 8 | `make install`, final `docs/VERIFICATION.md`, final commit | `/Applications/Quitter.app` running from login; all gates listed with evidence |
| 9 | Stretch only if 0–8 are green: per-group hotkeys | Recorder per group; hotkey quits the group without opening the panel |

## 10. Edge cases to handle (not optional)

- Two instances of one bundle (same bundle ID, different pids): both listed, names suffixed "(2)".
- `terminate()` returns `false` → `.stuck` immediately, no 5 s wait.
- App relaunches itself after quit (some helpers do): new pid = new row, old row exits normally.
- App quits by itself while `.requested` → handled by the poll, no special case.
- Panel open on a secondary display: use the status button's screen for positioning.
- Many menu bar icons / notch hides Quitter's icon: fallback position (see §7) and the hotkey still
  work.
- Settings opened while the panel is open: panel closes (it resigned key), Settings comes to front.
- Hotkey pressed while Settings is key: toggles the panel normally.
- Corrupt JSON in Application Support: renamed aside, app starts empty, never crashes.
- Swift 6: no `NSRunningApplication` or `NSImage` across actors. Icons are fetched on the main
  actor; sampling only gets `[pid_t]`.
- Running via `swift run`: no bundle → `Bundle.main.bundleIdentifier` is nil. Code must not force
  unwrap it; use the constant `"com.azizali.quitter"` for self-protection.

## 11. Code standards

- Swift 6 language mode, no force unwraps, no `try!`, no `any` erasure without reason.
- Every service behind a small protocol where a test needs to fake it (`Terminating`, clock).
- Semantic colours only; Dynamic Type not required (fixed macOS panel) but VoiceOver labels on
  checkboxes ("Quit Safari, 1.2 GB"), buttons, and chips are required.
- Commits: imperative mood, one per passed gate, author `Aziz Ali <aziz.alfta@gmail.com>`.
- Do not add dependencies beyond `KeyboardShortcuts`.
- Do not use private APIs or `showSettingsWindow:` selectors.
- Keep files under ~250 lines; split views when they grow.

## 12. Verification summary (what "done" means)

Quitter is done when `/Applications/Quitter.app` is installed, launches at login, and every gate in
§9 (0–8) has evidence in `docs/VERIFICATION.md`. Aziz's acceptance test, unchanged from the
original ask: open the panel, tick several apps, press Quit once, all of them quit.
