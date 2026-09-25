# Using the sim-use skill alongside jev-sim-use

jev-sim-use drives the device through [sim-use](https://github.com/lycorp-jp/sim-use). It is good at reaching a
screen in one command, but it deliberately offers Jev only a subset of sim-use: no double tap, no `type`, no raw
coordinates, no video. For those, and for checking results precisely, work with sim-use itself. sim-use ships its
own agent skill, which teaches its commands (aliases, selectors, gestures, screenshots, preflight checks).

## Install the sim-use skill

```sh
sim-use init                    # detects the AI client and installs the `sim-use` skill
sim-use init --client claude    # Claude Code: ~/.claude/skills/sim-use
sim-use init --client agents    # AGENTS.md-style clients
sim-use init --dest <dir>       # any skills directory
sim-use init --force            # update an existing install after upgrading sim-use
```

Once installed, the `sim-use` skill is available next to this one; load it when a step needs sim-use directly.
`sim-use init` only writes files on this machine; it does not touch any device.

## Which one to use

| Need | Use |
|---|---|
| Get to a screen, a setting, or a filled form in several steps | `jev-sim-use "<goal>"` |
| Read what is on screen, or verify a result | `jev-sim-use exec ui` (or `sim-use ui`) |
| One exact tap, a tap at coordinates, a held tap | `jev-sim-use exec tap @N` / `tap -x … -y … --duration 0.1` |
| Double tap, `type`, key presses, multi-touch, screenshots, video | sim-use, guided by its skill |
| Something jev-sim-use stopped on and cannot see (another process's prompt) | `exec screenshot`, then a coordinate tap |

`jev-sim-use exec <args>` runs `sim-use <args>` with the same device resolution, so everything in the sim-use skill
also works through `exec`.

## Things that matter when mixing them

- Pass the same `--device` to both when more than one simulator is booted. Aliases like `@12` come from the last
  `ui` read of that device; read the screen again after anything changes before tapping an alias.
- `resume` starts from whatever screen is showing, so it is fine to fix something by hand with sim-use and then
  continue the session.
