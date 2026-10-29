# Group 4: #808 osd.start `set -eu` prevents LUKS unlock of later OSDs

https://github.com/canonical/microceph/issues/808

## The problem

`snapcraft/commands/osd.start` runs under `set -eu` and unlocks and starts
every OSD in one loop. The issue reports that when one OSD failed, the
script exited and every later OSD on the node was never unlocked, so
encrypted OSDs stayed down after a reboot.

Half of that is fixed on main: the `ceph-osd` start is wrapped so a
failing OSD logs `failed to start; will retry`, sets `retry_pending` and
the loop moves on, with a 5 s retry timer around `spawn` (PR #788, from
#521). PR #929 made `maybe_unlock` accept an existing mapping.

What still aborts the whole script is the unlock step: `cryptsetup
luksOpen` failing (wrong key, device busy or gone), `get_key` failing
because the mon is not reachable yet (the empty key then trips
`${3:?missing}` in `maybe_unlock`), or either of those for a `.wal` or
`.db` device.

Decision: per-OSD unlock failures are logged and retried like start
failures already are, not fatal.

## Where

- `snapcraft/commands/osd.start`: `maybe_unlock` (13-26), `get_key`
  (28-32), `spawn` (42-77) with the three unlock blocks at 55-63 and the
  tolerant start at 70-74, the retry and reload loop at 82-111.
- `snapcraft/commands/common` is sourced at line 9.
- Tests: `tests/scripts/test_osd_start.py` (the `wrapper` fixture at line
  25 builds a fake snap tree and stubs `ceph-osd`, `nc` and `sleep`; there
  is no `cryptsetup` or `ceph` stub) and `tests/scripts/test_vaultlocker_reboot.py`.
- History: `git log -- snapcraft/commands/osd.start` (#680, #788, #929).
- CI gate: the `Checks` workflow, job `Run Unit tests` (Robot test `Run
  Python Helper Unit Tests` runs both pytest files). shellcheck is not
  run by CI on this script; reviewers run it.

## First job

Write a test in `test_osd_start.py` with two OSDs where the first one's
key cannot be fetched, and show the second never starts and the script
dies (`line 16: 3: missing`). The existing suite runs offline:
`python3 -m pytest -q tests/scripts/test_osd_start.py tests/scripts/test_vaultlocker_reboot.py`.

## Definition of done

- [ ] An unlock failure for one OSD (missing key, `luksOpen` failing, on
      the data, `.wal` or `.db` device) is logged, marked for retry, and
      the loop continues to the next OSD.
- [ ] The failed OSD comes up on a later pass once its key is available,
      without a service restart.
- [ ] Tests cover the missing-key and `luksOpen` failure cases and fail
      on main.
- [ ] Green: `python3 -m pytest -q tests/scripts/test_osd_start.py tests/scripts/test_vaultlocker_reboot.py`.
- [ ] `shellcheck -S warning snapcraft/commands/osd.start` exits 0.
- [ ] Run it with me on my VM; bring your osd.start. Before: with osd.0's
      key removed and both mappings closed, both OSDs stay down and the
      journal shows `line 16: 3: missing` and restarts. After: osd.0 logs
      an unlock failure every 5 s, osd.1 starts, and putting the key back
      brings osd.0 up on the next pass.
- [ ] Commit title `fix: <summary>` with `Fixes #808`.

## Watch out

- `${var:?}` exits the shell even inside a function and without `set -e`.
- `commands/common` has no shebang, so `shellcheck snapcraft/commands/*`
  is red on main (SC2148). Check `osd.start` alone.
- The fixture's `PATH` falls through to the host, so without a stub the
  real `/usr/sbin/cryptsetup` and `ceph` are reached.
- The unlock blocks test `[ -b ... ]`; the container has no block device
  to point at.
- The `trap`, timer and reload logic is covered by the existing tests;
  keep them green.
