# jev-sim-use

Drives an iOS Simulator or Android emulator toward a goal written in plain language.
[sim-use](https://github.com/lycorp-jp/sim-use) reads the screen and performs actions;
[Jev](https://docs.typesafe.ai/) (via [swift-jev](https://github.com/d-date/swift-jev))
picks the next action.

Jev does not write text, it answers typed questions. On each step jev-sim-use asks it two
things in one request: *is the goal reached?* (a probability) and *which of these actions
comes next?* (a choice over the elements sim-use found on screen, plus scroll, back, and
any texts you allowed it to paste).

```
observe (sim-use ui) → ask Jev → act (sim-use tap / gesture / button / paste) → repeat
```

## Requirements

- macOS 15+, Swift 6.2+
- sim-use 0.14.0 or newer on `PATH`:
  ```sh
  brew tap lycorp-jp/tap && brew install lycorp-jp/tap/sim-use
  ```
- A booted simulator or connected Android device (run `sim-use android init --device <serial>` once for Android)
- A TypeSafe API key (bring your own key)

## Usage

```sh
export TYPESAFE_API_KEY=...                       # read from the environment only
jev-sim-use doctor                                # checks sim-use, the device, and Jev settings
jev-sim-use "Turn on Dark Mode in Settings"
jev-sim-use "Search for ramen" -t ramen -d <sim-use device id>
jev-sim-use exec ui                               # any sim-use command, run as-is
jev-sim-use config set base-url https://proxy.example   # persist settings
```

From a checkout, use `swift run jev-sim-use ...`. The app must already be open, because
sim-use cannot launch apps. Progress goes to stderr and the final outcome to stdout.

| Option | Default | |
|---|---|---|
| `<goal>` | required | What to accomplish. Use `jev-sim-use run "doctor"` for a goal that collides with a subcommand |
| `-d, --device` | `$SIM_USE_DEVICE`, then the only usable device | A `deviceId` from `sim-use devices` |
| `-t, --text` | none | Text the agent may paste. Repeatable. Jev can only choose it, not write it |
| `--max-steps` | 15 | Upper bound on actions |
| `--min-confidence` | 0.6 | Stop and hand over when Jev is less sure than this |
| `--base-url` | `$TYPESAFE_BASE_URL`, then `config` `base-url`, then `https://api.typesafe.ai` | `/v1/systemone` is appended. HTTPS, or HTTP on localhost only |
| `--model` | `$TYPESAFE_MODEL`, then `config` `model`, then `jev-latest` | |

`config` stores `base-url` and `model` in `$XDG_CONFIG_HOME/jev-sim-use/config.json`
(default `~/.config`). The API key is never stored.

To use Jev through another provider (e.g. Cloudflare Workers AI), put a proxy that speaks
TypeSafe's `POST /v1/systemone` format in front of it and point `base-url` at the proxy.

Exit status: 0 goal reached, 1 goal not reached, 2 setup error (sim-use, device, key, URL),
3 sim-use or Jev failure, 64 invalid arguments. `exec` exits with sim-use's own status.

Each step sends the screen outline (visible labels and values), your goal, the action history,
and every `--text` value to the Jev endpoint. Do not run it on screens with data you may not share.

A run also stops when three actions in a row leave the screen unchanged, when the app
disappears, or when an Android crash dialog appears.

## When sim-use changes

jev-sim-use talks to sim-use only through its CLI and `--json` output; every name it passes lives in
`SimUseContract`. It was verified against sim-use 0.14.0, warns (without stopping) on newer versions, and
`jev-sim-use doctor` reads the screen once to catch output changes early. After upgrading sim-use, run
`mise run contract-test` with a booted device: it checks each subcommand's `--help` and decodes real
`devices` / `ui` output.

## License

This repository does not declare a license yet. Third-party notices are in
[THIRD_PARTY_LICENSES](THIRD_PARTY_LICENSES). sim-use (Apache-2.0) is invoked as a separate
process and is not bundled.
