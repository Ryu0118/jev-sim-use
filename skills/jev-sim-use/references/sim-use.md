# Using sim-use alongside jev-sim-use

jev-sim-use drives the device through [sim-use](https://github.com/lycorp-jp/sim-use) and offers Jev only part of
what sim-use can do. Reading the screen, checking a result, single exact actions, and anything Jev is not offered
are done with sim-use itself, either directly or through `jev-sim-use exec <sim-use args>`, which runs sim-use against
the same device.

sim-use's commands change between releases, so this skill does not describe them. Learn them from sim-use:

- Install sim-use's own agent skill, which teaches its commands and is kept in step with the installed version. See
  `sim-use init --help` for how to install it for your client, and reinstall it after upgrading sim-use.
- For any command, `sim-use --help` and `sim-use <command> --help` are the reference.

Once the sim-use skill is installed, load it whenever a step needs sim-use directly, and use jev-sim-use for the
multi-step navigation in between. A session's `resume` starts from whatever screen is showing, so fixing something
by hand with sim-use and then continuing is fine.
