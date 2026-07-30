# Agent notes for Pixel Cat

A pixel-art desktop pet for macOS. Swift/AppKit, built with SwiftPM — no Xcode
project, no external dependencies. The README covers user-facing behavior
(controls, scripting files, art format); this file covers what you need to
work on the code.

## Build and test

    make test     # swift test — the full unit suite
    make run      # build release, assemble PixelCat.app, relaunch it
    make build    # binary only
    make art      # regenerate placeholder sprite sheets from Tools/GenerateArt.swift

`make run` kills any running instance first. Testing a behavior change on the
live desktop app always requires `make run` — the app does not hot-reload.

## Architecture

Two targets with a deliberate split:

- **`PixelCatCore`** — pure logic, no AppKit import. Animation rules, sprite
  geometry, manifest parsing, state decisions (`CatBrain`), file watching
  (`FileTokenWatcher`), phrases/learning (`Phrases`, `PhraseStore`,
  `OvernightLearning`). Everything here is unit tested.
- **`PixelCat`** — the AppKit shell: windows, drawing, menu bar, timers,
  `SpeechController`. **Untested by design** — keep it thin. If a change
  involves logic that could live in Core, put it in Core and test it there.

## Conventions

- Tests use Swift Testing (`@Suite`, `@Test`, `#expect`) — not XCTest.
  Match the style of the existing files in `Tests/PixelCatCoreTests/`.
- Timers in the app target use the target/selector API and are added to
  `RunLoop.main` with mode `.common`. Closure-based timers need `@Sendable`
  and break `@MainActor` classes; `.common` keeps timers firing during
  drags and menu tracking. Follow this pattern for any new timer.
- Randomness in Core is injected (a `roll` parameter or a passed-in RNG) so
  tests are deterministic. Dates and calendars are parameters too — see
  `OvernightLearning.shouldActivate(now:lastActivation:calendar:)`.
- Animals are discovered by enumerating `Resources/animals/`; menus and
  state lists are built from what's found. New animals/states are data
  changes (PNG + JSON), not Swift changes. Don't hardcode animal or state
  names in the app — the one sanctioned exception is
  `SpeechController.disturbedStates`.
- `Tools/generate-phrases.sh` hardcodes the state-tag list (`TAGS`); keep it
  in sync if states change.

## Runtime state (outside the repo)

- `~/.config/pixelcat/` — control files (`state`, `animal`, `say`, `learn`)
  plus persistent data (`phrases`, `backlog`). The control files are
  consumed/watched; see the README "Scripting" and "Speech" sections.
- UserDefaults domain `com.markbiek.pixelcat` — keys `catOriginX`,
  `catOriginY`, `selectedAnimal`, `lastLearnActivation`.
- launchd agent `com.markbiek.pixelcat.phrases` (nightly phrase generation,
  2:30 AM), log at `~/Library/Logs/pixelcat-phrases.log`.

## Gotchas

- **Wall-clock thresholds:** compute "4 AM today" with
  `calendar.date(bySettingHour:minute:second:of:)`, never
  `byAdding: .hour` from start-of-day — the latter is wrong on DST
  transition days. There are regression tests pinning this.
- **`FileTokenWatcher`** does a kqueue dual watch (directory + file inode)
  so it survives the watched file being deleted and recreated. The app
  deletes `say`/`learn` after reading; blank contents are deliberately
  treated as "nothing" to avoid phantom re-delivery.
- **`SpeechBubbleWindow`** is a child window of the cat window, so it
  follows drags for free. Don't reposition it manually on move.
- `Manifest` deliberately ignores legacy per-animal `cellSize`/`scale`
  fields — those are global in `animals.json` only.

## Process

- Plan and design docs go in `~/notes/assistant/Research/`, never in this
  repo.
