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
- 🎯 **Jev chooses, never invents**: every action comes from what is on screen, and it only types text you pass with `-t`

## Installation

Requires macOS 15+, Swift 6.2+, and sim-use 0.14.0+:

```sh
brew tap lycorp-jp/tap && brew install lycorp-jp/tap/sim-use
```

```sh
git clone https://github.com/Ryu0118/jev-sim-use.git
cd jev-sim-use
swift build -c release
cp .build/release/jev-sim-use /usr/local/bin/
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
jev-sim-use "Search for ramen" -t ramen
```

---

## Using it from an agent

Add a line like this to your project's `CLAUDE.md`, so the agent delegates navigation instead of tapping step by step:

```md
To reach a screen in the simulator, run `jev-sim-use "<goal>"` (exit 0 means it got there).
Use sim-use directly only to inspect or verify the screen once you are there.
```

---

## What leaves your machine

Each step sends the screen outline (visible labels and values), your goal, the action history, and every `-t` value
to the Jev endpoint. Do not run it on screens with data you may not share.

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
```

| Option | Default | |
|---|---|---|
| `-d, --device` | `$SIM_USE_DEVICE`, then the only usable device | A `deviceId` from `sim-use devices` |
| `-t, --text` | none | Text it may paste. Repeatable |
| `--max-steps` | 15 | |
| `--min-confidence` | 0.6 | Stops and hands over when Jev is less sure |
| `--base-url` | `$TYPESAFE_BASE_URL`, then `config`, then `https://api.typesafe.ai` | HTTPS, or HTTP on localhost |
| `--model` | `$TYPESAFE_MODEL`, then `config`, then `jev-latest` | |

The API key is read only from `TYPESAFE_API_KEY` and never stored. Settings live in
`$XDG_CONFIG_HOME/jev-sim-use/config.json` (default `~/.config`).

Exit status: 0 goal reached, 1 not reached, 2 setup error, 3 sim-use or Jev failure. `exec` passes sim-use's status through.

---

## License

No license yet. Third-party notices are in [THIRD_PARTY_LICENSES](THIRD_PARTY_LICENSES).
