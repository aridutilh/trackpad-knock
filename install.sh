#!/bin/sh
# Builds knock, installs it to ~/.local/bin, and adds a Claude Code Stop hook
# so the trackpad knocks twice whenever Claude finishes a turn.
set -eu
cd "$(dirname "$0")"

BIN="$HOME/.local/bin/knock"
SETTINGS="$HOME/.claude/settings.json"

command -v clang >/dev/null || { echo "clang not found. Run: xcode-select --install"; exit 1; }

mkdir -p "$(dirname "$BIN")"
clang -O2 -fobjc-arc -framework Foundation knock.m -o "$BIN"
echo "Built $BIN"

mkdir -p "$(dirname "$SETTINGS")"
[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"
cp "$SETTINGS" "$SETTINGS.knock-backup"

python3 - "$SETTINGS" "$BIN" <<'PY'
import json, sys
path, binary = sys.argv[1], sys.argv[2]
with open(path) as f:
    settings = json.load(f)
stop = settings.setdefault("hooks", {}).setdefault("Stop", [])
if any("/knock" in h.get("command", "") for group in stop for h in group.get("hooks", [])):
    print("Stop hook already present, left as is")
else:
    stop.append({"hooks": [{"type": "command", "command": f"{binary} 2>/dev/null || true", "timeout": 5}]})
    with open(path, "w") as f:
        json.dump(settings, f, indent=2)
        f.write("\n")
    print(f"Added Stop hook to {path} (backup at {path}.knock-backup)")
PY

"$BIN" && echo "You should have just felt two knocks. Restart Claude Code to pick up the hook."
