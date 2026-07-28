# Pixel Cat

A pixel-art cat that lives on your macOS desktop. It floats above your windows,
animates, picks its own moods, and can be dragged anywhere. It runs from the
menu bar with no Dock icon.

## Requirements

macOS 14 or later, and the Xcode command line tools:

    xcode-select --install

## Build and run

    git clone <this repo> && cd pixelcat
    make run

`make` builds `PixelCat.app` in the repo directory. Move it to `/Applications`
if you want to keep it, and add it to Login Items to start it automatically.

This app is not signed with an Apple Developer certificate. Building it yourself
avoids Gatekeeper entirely — quarantine is only applied to things downloaded
from the internet, not to what you compile locally.

## Controls

The menu bar icon offers:

- A list of states to pin the cat to
- **Let the Cat Decide** — resume autonomous mood changes
- **Reset Position** — bring the cat back to the lower right
- **Quit Pixel Cat**

Drag the cat anywhere. It remembers where you left it.

## Scripting the cat

Write a state name to `~/.config/pixelcat/state` and the cat obeys:

    echo dance > ~/.config/pixelcat/state
    echo sleep > ~/.config/pixelcat/state
    echo auto  > ~/.config/pixelcat/state    # resume autonomous behavior

Anything that can write a file can drive the cat — a shell script, a cron job, a
git hook. Unrecognized names are ignored.

Pinning a state stops the cat choosing for itself until you write `auto` or use
the menu.

The signal file is not read at launch — only watched. A signal left over from
a previous session has no effect until something writes to the file again.

## Changing the art

The cat is a sprite sheet, `Resources/cat.png`, described by
`Resources/states.json`:

    {
      "cellSize": 24,
      "scale": 3,
      "defaultState": "idle",
      "decideIntervalSeconds": [8, 20],
      "states": {
        "idle":  { "row": 0, "frames": 4, "fps": 4,  "weight": 70 },
        "sleep": { "row": 1, "frames": 2, "fps": 1,  "weight": 20 },
        "dance": { "row": 2, "frames": 6, "fps": 10, "weight": 10 }
      }
    }

- `cellSize` is the pixel size of one square cell in the sheet
- `scale` multiplies that for the on-screen window
- `row` is counted from the **top** of the image
- `weight` is the relative chance of the cat picking that state
- `decideIntervalSeconds` is the `[min, max]` gap between mood changes

Adding a state means adding a row to the PNG and an entry to the JSON. No Swift
changes are needed, and the new state appears in the menu automatically.

The bundled art is a placeholder: a black-and-white cat, 24px cells shown at
72 points on screen. To regenerate it after editing `Tools/GenerateArt.swift`:

    make art

## Development

    make test     # unit tests
    make build    # binary only
    make clean

Animation rules, sprite geometry, and signal parsing live in `PixelCatCore`,
which has no AppKit dependency and is unit tested. `PixelCat` is the AppKit
shell: window, drawing, menu bar, and timers.
