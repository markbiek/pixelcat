# Pixel Cat

A pixel-art cat that lives on your macOS desktop. It floats above your windows,
animates, picks its own moods, and can be dragged anywhere. It runs from the
menu bar with no Dock icon.

<img width="290" height="140" alt="image" src="https://github.com/user-attachments/assets/5590507f-903c-4e49-8872-c7173ac71499" />

<img width="440" height="140" alt="image" src="https://github.com/user-attachments/assets/237b8b43-151d-46a5-9701-0b84c905372a" />

<img width="290" height="140" alt="image" src="https://github.com/user-attachments/assets/9d54af45-d836-48a9-b352-5bfa08e68d17" />

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

- **Animal** — a submenu picking which animal is on screen. The choice is
  remembered across launches.
- A list of states to pin the current animal to. Each animal has its own
  states, so this list changes when you switch animals.
- **Let the Cat Decide** — resume autonomous mood changes
- **Reset Position** — bring the cat back to the lower right
- **Quit Pixel Cat**

Drag the cat anywhere. It remembers where you left it.

## Scripting the cat

Two files under `~/.config/pixelcat` drive the app. Write a state name to
`state`, or an animal name to `animal`:

    echo dance > ~/.config/pixelcat/state     # pick a state
    echo auto  > ~/.config/pixelcat/state     # resume autonomous behavior
    echo bat   > ~/.config/pixelcat/animal    # pick an animal

Anything that can write a file can drive the cat — a shell script, a cron job, a
git hook. Unrecognized names are ignored. Writing `animal` this way also updates
the remembered choice for next launch, exactly as picking it from the menu does.

Each animal has its own states, so a name valid for one animal may be ignored by
another: `wag` moves the dog and means nothing to the bat.

Pinning a state stops the cat choosing for itself until you write `auto` or use
the menu. Switching animals also starts fresh, so a pinned state does not
survive the switch.

Neither file is read at launch — only watched. A signal left over from a
previous session has no effect until something writes to the file again.

## Speech

The cat occasionally says things in a little bubble. Its vocabulary lives in
`~/.config/pixelcat/phrases` — one phrase per line, editable by hand. A line
may start with a state name to tie the phrase to a mood:

    mew
    sleep: five more minutes
    dance: watch this

Untagged phrases can come up any time; tagged ones only while the animal is
in that state. Tags that no animal state matches are ignored. All animals
share one vocabulary.

Two more files under `~/.config/pixelcat` drive speech:

    echo "hello there" > ~/.config/pixelcat/say     # say this now, once
    echo "new phrase"  > ~/.config/pixelcat/learn   # learn this overnight

`say` shows a bubble immediately and is not remembered. `learn` accepts one
or more lines (state tags allowed) and queues them in
`~/.config/pixelcat/backlog`; the cat studies while you sleep — the first
time it's awake after 4 AM, the backlog joins its vocabulary and it
announces what it learned. Both files are consumed after reading.

`say` also accepts an optional second line starting with `run:` — a shell
command run if you click the bubble, useful for jumping to whatever sent
the notification:

    printf 'build done\nrun: open -a Terminal\n' > ~/.config/pixelcat/say

The `run:` marker makes execution opt-in: a second line without it is
ignored, so multi-line text piped into `say` stays inert. Clickable
bubbles stick around longer than regular ones. Bubbles without a command
(including all of the cat's own chatter) ignore clicks entirely, so they
never get in the way of windows beneath them.

Anything that can write a file can teach the cat. A nightly cron feeding
`learn` from an LLM, a script, or your own typing all work the same way.

`Tools/generate-phrases.sh` is one such generator: it asks an LLM
(`claude -p`, falling back to ollama) for a few new phrases and appends
them to `learn`. Run it by hand to test, or `--install` to load a launchd
agent that runs it nightly at 2:30 AM — in time for the 4 AM drain.

## Changing the art

`Resources/animals.json` holds the settings every animal shares:

    {
      "cellSize": 24,
      "scale": 3,
      "defaultAnimal": "cat"
    }

- `cellSize` is the pixel size of one square cell in a sheet
- `scale` multiplies that for the on-screen window
- `defaultAnimal` is shown on first launch, before you have picked one

Each animal is a pair of files in `Resources/animals`: a sprite sheet
`<name>.png` and a manifest `<name>.json`. The bundled animals are `cat`, `dog`,
and `bat`. Here is `Resources/animals/cat.json`:

    {
      "defaultState": "idle",
      "decideIntervalSeconds": [8, 20],
      "states": {
        "idle":  { "row": 0, "frames": 4, "fps": 4,  "weight": 70 },
        "sleep": { "row": 1, "frames": 2, "fps": 1,  "weight": 20 },
        "dance": { "row": 2, "frames": 6, "fps": 10, "weight": 10 }
      }
    }

- `row` is counted from the **top** of the image
- `frames` is how many cells that row uses, starting at the left
- `fps` is that state's playback rate
- `weight` is the relative chance of the animal picking that state
- `decideIntervalSeconds` is the `[min, max]` gap between mood changes

Adding a state means adding a row to that animal's PNG and an entry to its JSON.
Adding a whole animal means dropping a new `<name>.png` and `<name>.json` pair
into `Resources/animals`. Either way no Swift changes are needed — animals are
discovered by enumerating the bundle, and both the animal submenu and the state
list are built from what is found.

All animals share the one `cellSize` and `scale` from `animals.json`, so a new
animal must be drawn on the same 24px grid as the existing ones.

The bundled art is a placeholder: black-and-white animals, 24px cells shown at
72 points on screen. To regenerate it after editing `Tools/GenerateArt.swift`:

    make art

## Development

    make test     # unit tests
    make build    # binary only
    make clean

Animation rules, sprite geometry, and signal parsing live in `PixelCatCore`,
which has no AppKit dependency and is unit tested. `PixelCat` is the AppKit
shell: window, drawing, menu bar, and timers.
