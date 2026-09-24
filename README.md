# SimJevUse

Drives an iOS Simulator or Android emulator toward a goal written in plain language.
[sim-use](https://github.com/lycorp-jp/sim-use) reads the screen and performs actions;
[Jev](https://docs.typesafe.ai/) (via [swift-jev](https://github.com/d-date/swift-jev))
picks the next action.

Jev does not write text, it answers typed questions. On each step SimJevUse asks it two
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
export TYPESAFE_API_KEY=...        # never passed as a flag
swift run SimJevUse doctor         # checks sim-use, the device, and Jev settings
swift run SimJevUse run --goal "Turn on Dark Mode in Settings"
swift run SimJevUse run --goal "Search for ramen" --text "ramen" --device <sim-use device id>
```

The app must already be open, because sim-use cannot launch apps. Progress goes to stderr.
The final outcome goes to stdout, and the exit status is 0 only when the goal is reached.

| Option | Default | |
|---|---|---|
| `--goal` | required | What to accomplish |
| `--device` | the only usable device | A `deviceId` from `sim-use devices` |
| `--text` | none | Text the agent may paste. Repeatable. Jev can only choose it, not write it |
| `--max-steps` | 15 | Upper bound on actions |
| `--min-confidence` | 0.6 | Stop and hand over when Jev is less sure than this |
| `--endpoint` | `$TYPESAFE_ENDPOINT`, then `https://api.typesafe.ai/v1/systemone` | The full evaluation URL. HTTPS, or HTTP on localhost only |
| `--model` | `$TYPESAFE_MODEL`, then `jev-latest` | |

A run also stops when three actions in a row leave the screen unchanged, when the app
disappears, or when an Android crash dialog appears.

## License

This repository does not declare a license yet. Third-party notices are in
[THIRD_PARTY_LICENSES](THIRD_PARTY_LICENSES). sim-use (Apache-2.0) is invoked as a separate
process and is not bundled.
