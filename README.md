# 📱 jev-sim-use

**Reach any screen with sim-use at Jev speed, in one command instead of an agent turn per tap.**

jev-sim-use is a fast navigator for iOS Simulator and Android devices.
[sim-use](https://github.com/lycorp-jp/sim-use) lets AI agents drive a device, but when a frontier LLM such as
Claude Code runs the loop, every tap costs a full reasoning turn. jev-sim-use hands that loop to
[Jev](https://docs.typesafe.ai/), a small model that answers typed questions: each step is one request that returns
"is the goal reached?" and "which on-screen action comes next?". Give it a goal like "Turn on Dark Mode in Settings"
and it taps its way there on its own. Each step sends the screen's visible labels and values to the Jev API.

## Features

- ⚡ **Ultrafast navigation** — one small Jev call per step instead of a full LLM agent turn
- 🔁 **Hands over, then picks up again** — when Jev is stuck it stops with a session your agent can inspect, teach, and resume
- 🎯 **Jev chooses, never invents** — every action comes from what is on screen, and it only enters text you pass with `-t name=value`

## Installation

Requires macOS 15+ and sim-use 0.14.0+:

```sh
brew tap lycorp-jp/tap && brew install lycorp-jp/tap/sim-use
```

```sh
curl -fsSL https://raw.githubusercontent.com/Ryu0118/jev-sim-use/main/install.sh | bash
```

To update, run the same command. It skips the download if already up-to-date.

```sh
# Install a specific version
curl -fsSL https://raw.githubusercontent.com/Ryu0118/jev-sim-use/main/install.sh | VERSION=0.1.0 bash

# Force reinstall
curl -fsSL https://raw.githubusercontent.com/Ryu0118/jev-sim-use/main/install.sh | FORCE=1 bash
```

### Other methods

#### Mise ([jdx/mise](https://github.com/jdx/mise))

```sh
mise use -g github:Ryu0118/jev-sim-use
```

#### Nest ([mtj0928/nest](https://github.com/mtj0928/nest))

```sh
nest install Ryu0118/jev-sim-use
```

---

## Quick start

1. Boot a simulator, or connect an Android device and run `sim-use android init --device <serial>` once.
2. Open the app you want to drive. sim-use cannot launch apps.
3. Run:

```sh
export TYPESAFE_API_KEY=...
jev-sim-use doctor
jev-sim-use "Turn on Dark Mode in Settings"
```

### Entering text

Jev never writes text. Name each string the goal needs; Jev matches the name to a field's label, and the value is
entered for it without being sent to Jev:

```sh
jev-sim-use "In Maps, search for ramen and show the results" -t query=ramen
jev-sim-use "Log in to the app" -t email=alice@example.com -t password=hunter2
```

### Choosing a device

With one booted simulator or connected Android device, it is picked automatically. With several, pass one:

```sh
jev-sim-use exec devices                          # list deviceIds
jev-sim-use "Turn on Dark Mode in Settings" -d <deviceId>
```

Physical iPhones are not supported.

### Any sim-use command

`exec` runs sim-use with your arguments unchanged, so one tool covers both fast navigation and precise checks:

```sh
jev-sim-use exec ui
jev-sim-use exec screenshot
```

---

## When Jev gets stuck

Jev picks well among what is on screen, but it cannot know where an off-screen setting lives or what an app-specific
label means. When it is unsure, it stops before guessing and leaves a session, so a person or your agent can supply
the missing fact and let it continue from where it stopped:

```sh
$ jev-sim-use "Turn on Dark Mode"
Stopped at step 9: Jev's best action (Tap the Button labelled "一般") had confidence 0.19, below the threshold.
Session: 9948937e

$ jev-sim-use session show        # goal, notes, how each run ended, every action taken
$ jev-sim-use exec ui             # the screen it stopped on
$ jev-sim-use session tell -n "Dark Mode is the ダークの外観モード switch on the デベロッパ screen"
$ jev-sim-use session tell -n "The goal is reached when that switch is on"
$ jev-sim-use session resume      # same goal, with your notes and the history so far
Goal reached after 8 action(s).
```

Notes are facts Jev reads on every later step; remove a wrong one with `session forget -n <number>`. A session is
deleted when its goal is reached, and expires a week after it last changed. The installed skill teaches your agent
this loop, so it can step in without you.

---

## Agent skill

The `jev-sim-use` skill teaches your agent to delegate navigation to one command instead of tapping step by step.

```sh
jev-sim-use skill install --client claude    # ~/.claude/skills
jev-sim-use skill install --client agents    # ~/.agents/skills (Codex and other AGENTS-style clients)
```

Or install it as a plugin or package:

```sh
# Claude Code
/plugin marketplace add Ryu0118/jev-sim-use
/plugin install jev-sim-use@jev-sim-use

# Codex
codex plugin marketplace add Ryu0118/jev-sim-use
codex plugin add jev-sim-use@jev-sim-use

# APM
apm install Ryu0118/jev-sim-use

# GitHub CLI
gh skill install Ryu0118/jev-sim-use jev-sim-use --agent claude-code

# skills CLI
npx skills add Ryu0118/jev-sim-use --all
```

---

## Other providers

Put a proxy that speaks TypeSafe's `POST /v1/systemone` format in front of the provider, then point jev-sim-use at it:

```sh
jev-sim-use config set base-url https://proxy.example
```

---

## Command reference

```
jev-sim-use [run] <goal> [options]   work toward a goal (default command)
jev-sim-use session list|show|tell|forget|resume   inspect, teach, and continue a stopped run
jev-sim-use doctor                   check sim-use, the device, and Jev settings
jev-sim-use exec <sim-use args...>   run a sim-use command as-is
jev-sim-use config get|set|unset|list  base-url, model
jev-sim-use skill install|uninstall|print  the agent skill (--client claude|agents or --dest <dir>)
```

| Option | Default | |
|---|---|---|
| `-d, --device` | the only usable device | A `deviceId` from `sim-use devices` |
| `-t, --text` | none | `name=value` to enter into a field; Jev sees only the name. Repeatable |
| `--max-steps` | 15 | Per run; `session resume` gets a fresh budget |
| `--min-confidence` | 0.55 | Below this, it hands over instead of guessing |
| `--actions` | all | Comma-separated operation groups Jev may choose from (`tap`, `type`, `scroll`, `back`, `return`, `long-press`, `swipe`, `pinch`, `rotate`, `buttons`, `wait`) |
| `--base-url` | `$TYPESAFE_BASE_URL`, then `config`, then `https://api.typesafe.ai` | HTTPS, or HTTP on localhost |
| `--model` | `$TYPESAFE_MODEL`, then `config`, then `jev-1.13.0` (pinned; `jev-latest` also works) | |

The API key is read only from `TYPESAFE_API_KEY` and never stored. Settings live in
`$XDG_CONFIG_HOME/jev-sim-use/config.json` (default `~/.config`).

---

## License

MIT. See [LICENSE](LICENSE). Third-party notices are in [THIRD_PARTY_LICENSES](THIRD_PARTY_LICENSES).
