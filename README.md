# jev-sim-use

**sim-use at Jev speed: reach any screen with one command instead of an agent turn per tap.**

jev-sim-use is a fast navigator for iOS Simulator and Android devices.
[sim-use](https://github.com/lycorp-jp/sim-use) lets AI agents drive a device, but when a frontier LLM such as
Claude Code runs the loop, every tap costs a full reasoning turn. jev-sim-use hands that loop to
[Jev](https://docs.typesafe.ai/), a small model that answers typed questions: each step is one request that returns
"is the goal reached?" and "which on-screen action comes next?". Give it a goal like "Turn on Dark Mode in Settings"
and it taps its way there on its own.

## Features

- ⚡ **Ultrafast navigation**: one small Jev call per step instead of a full LLM agent turn
- 🤖 **One command for your agent**: Claude Code delegates "get to that screen" and spends its turns on the real work
- 🎯 **Jev chooses, never invents**: every action comes from what is on screen, and it only enters text you pass with `-t name=value`

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
jev-sim-use "In Maps, search for ramen and show the results" -t query=ramen
jev-sim-use "Log in to the app" -t email=alice@example.com -t password=hunter2
```

The app must already be open. Jev chooses actions but never writes text. When a goal needs typing, pass each string
as `-t name=value` (`--text`), once per string. Jev sees only the name (`email`, `password`) and matches it to a
field's label; jev-sim-use then enters the value. Values are never sent to Jev; unfinished sessions keep them
locally (readable only by you) so `session resume` can enter them.

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

## What leaves your machine

Each step sends the screen outline (visible labels and values), your goal, the action history, the session notes, and
the names of your `-t` texts to the Jev endpoint. The `-t` values stay on your machine. Do not run it on screens with data you may not share.

## Other providers

Put a proxy that speaks TypeSafe's `POST /v1/systemone` format in front of the provider, then point jev-sim-use at it:

```sh
jev-sim-use config set base-url https://proxy.example
```

---

## Command reference

```
jev-sim-use [run] <goal> [options]   work toward a goal (default command)
jev-sim-use doctor                   check sim-use, the device, and Jev settings
jev-sim-use exec <sim-use args...>   run a sim-use command as-is
jev-sim-use config get|set|unset|list  base-url, model
jev-sim-use skill install|uninstall|print  the agent skill (--client claude|agents or --dest <dir>)
```

| Option | Default | |
|---|---|---|
| `-d, --device` | the only usable device | A `deviceId` from `sim-use devices` |
| `-t, --text` | none | `name=value` to enter into a field; Jev sees only the name. Repeatable |
| `--max-steps` | 15 | |
| `--min-confidence` | 0.6 | Stops and hands over when Jev is less sure |
| `--base-url` | `$TYPESAFE_BASE_URL`, then `config`, then `https://api.typesafe.ai` | HTTPS, or HTTP on localhost |
| `--model` | `$TYPESAFE_MODEL`, then `config`, then `jev-1.13.0` (pinned; `jev-latest` also works) | |

The API key is read only from `TYPESAFE_API_KEY` and never stored. Settings live in
`$XDG_CONFIG_HOME/jev-sim-use/config.json` (default `~/.config`).

Exit status: 0 goal reached, 1 not reached, 2 setup error, 3 sim-use or Jev failure. `exec` passes sim-use's status through.

---

## License

MIT. See [LICENSE](LICENSE). Third-party notices are in [THIRD_PARTY_LICENSES](THIRD_PARTY_LICENSES).
