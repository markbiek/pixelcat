#!/bin/bash
# Nightly phrase generator for Pixel Cat.
#
# Asks an LLM for a few new phrases and appends them to
# ~/.config/pixelcat/learn, where the app's overnight-learning mechanic
# picks them up (see README "Speech"). Tries `claude -p` first, falls back
# to ollama, and skips the night quietly if neither works — the cat just
# doesn't learn anything new that day.
#
# Run it once by hand to test, or `generate-phrases.sh --install` to load
# a launchd agent that runs it at 2:30 AM (launchd, not cron, so a sleeping
# laptop runs the job at next wake — in time for the app's 4 AM drain).

set -u

# launchd jobs get a bare PATH; cover the usual homes of claude and ollama.
export PATH="$HOME/.local/bin:$HOME/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

CONFIG_DIR="$HOME/.config/pixelcat"
LEARN_FILE="$CONFIG_DIR/learn"
PHRASES_FILE="$CONFIG_DIR/phrases"
PLIST_LABEL="com.markbiek.pixelcat.phrases"
PLIST_PATH="$HOME/Library/LaunchAgents/$PLIST_LABEL.plist"
LOG_PATH="$HOME/Library/Logs/pixelcat-phrases.log"

# Keep in sync with Resources/animals/*.json state names.
TAGS="idle, sleep, dance, wag, fly, hang, hop, melt, ripple, chew"

install_agent() {
    local script_path
    script_path="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
    mkdir -p "$(dirname "$PLIST_PATH")"
    cat > "$PLIST_PATH" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>$PLIST_LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$script_path</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key><integer>2</integer>
        <key>Minute</key><integer>30</integer>
    </dict>
    <key>StandardOutPath</key><string>$LOG_PATH</string>
    <key>StandardErrorPath</key><string>$LOG_PATH</string>
</dict>
</plist>
PLIST
    launchctl bootout "gui/$(id -u)" "$PLIST_PATH" 2>/dev/null
    launchctl bootstrap "gui/$(id -u)" "$PLIST_PATH"
    echo "installed $PLIST_LABEL (2:30 AM nightly, log: $LOG_PATH)"
}

build_prompt() {
    local known=""
    [ -f "$PHRASES_FILE" ] && known="$(cat "$PHRASES_FILE")"
    cat <<PROMPT
You write dialogue for a tiny pixel-art desktop pet (a cat, dog, or bat).
Write 5 new things it might say: short, dry, charming — a few words each,
never more than 60 characters. Mix plain lines with mood-tagged lines.
A mood tag is one of ($TAGS) followed by a colon, e.g. "sleep: five more minutes".

Output ONLY the 5 lines, one per line. No numbering, no bullets, no quotes,
no introduction, no commentary.

Do not repeat any of these, which it already knows:
$known
PROMPT
}

# Drop bullets/numbering/quotes the model was told not to add anyway, then
# anything that still looks like commentary rather than a phrase.
sanitize() {
    sed -e 's/\r$//' \
        -e 's/^[-*•]\s*//' \
        -e 's/^[0-9]\{1,2\}[.)]\s*//' \
        -e 's/^"\(.*\)"$/\1/' \
        -e "s/^'\(.*\)'$/\1/" \
    | grep -v -i 'phrase' \
    | awk 'length($0) > 0 && length($0) <= 80' \
    | head -8
}

generate() {
    local prompt output
    prompt="$(build_prompt)"

    if command -v claude >/dev/null 2>&1; then
        output="$(claude --model haiku -p "$prompt" 2>/dev/null | sanitize)"
        if [ -n "$output" ]; then
            echo "$output"
            return 0
        fi
        echo "claude produced nothing usable, trying ollama" >&2
    fi

    if command -v ollama >/dev/null 2>&1; then
        output="$(ollama run llama3.2 "$prompt" 2>/dev/null | sanitize)"
        if [ -n "$output" ]; then
            echo "$output"
            return 0
        fi
    fi

    return 1
}

if [ "${1:-}" = "--install" ]; then
    install_agent
    exit 0
fi

if phrases="$(generate)"; then
    mkdir -p "$CONFIG_DIR"
    printf '%s\n' "$phrases" >> "$LEARN_FILE"
    echo "$(date '+%F %T') taught: $(printf '%s' "$phrases" | tr '\n' '|')"
else
    echo "$(date '+%F %T') no generator available; skipping tonight" >&2
    exit 0
fi
