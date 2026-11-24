# trackpad-knock

Your MacBook's trackpad knocks twice when Claude Code finishes a turn. No sound, no banner: you feel it under your hand, and on a hard desk you can faintly hear it even with the Mac muted.

## Install

Needs a MacBook (or Magic Trackpad 2 or later), Claude Code, and the Xcode Command Line Tools (`xcode-select --install`).

```sh
git clone https://github.com/aridutilh/trackpad-knock
cd trackpad-knock
./install.sh
```

The script compiles `knock`, puts it in `~/.local/bin`, and adds a Stop hook to `~/.claude/settings.json` (it backs the file up first). You should feel two knocks when it finishes. Restart Claude Code afterward.

## Patterns

| Command | Feel | Suggested meaning |
| --- | --- | --- |
| `knock done` | two knocks on wood | agent finished |
| `knock ask` | three rising ticks | agent is waiting on you |
| `knock error` | one long low buzz | something failed |

Only `done` is wired up by the installer. To also get the rising ticks when Claude is waiting on a permission prompt, add a Notification hook next to the Stop hook:

```json
"Notification": [
  { "hooks": [{ "type": "command", "command": "~/.local/bin/knock ask 2>/dev/null || true" }] }
]
```

## Uninstall

Open `/hooks` in Claude Code and remove the `knock` entry, then `rm ~/.local/bin/knock`.

## How it works

`knock.m` is about 90 lines of Objective-C. It drives the Force Touch haptic motor through macOS's private `MultitouchSupport` framework, sending it a short recipe of sine tones. Because the framework is private, this can break on any macOS update.

## Credits

The technique comes from [os6/nospeaker](https://github.com/os6/nospeaker) by Cody Collier and [asadm/mechpad](https://github.com/asadm/mechpad), both MIT licensed.
