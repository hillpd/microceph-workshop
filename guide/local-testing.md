# Testing locally

Reference; the [cheat sheet](cheatsheet.md) has the commands.

Everything here works offline from the bundle except where marked.

## The map

| CI workflow | Job | What it runs | Local equivalent |
|---|---|---|---|
| `Checks` | `static-checks` | Robot suite `tests/robot/static-checks`: `make check-static` (golangci-lint) and `go vet ./...` | `tox -e robot -- --test-suite static-checks` |
| `Checks` | `unit-tests` | Robot suite `tests/robot/unit-tests`: `make check-unit`, the shell unit tests in `tests/scripts/*.sh`, the pytest files in `tests/scripts/` and `tests/robot/resources/`, and the `microceph-orch` module tests | `tox -e robot -- --test-suite unit-tests` |
| `Commits` | DCO | `Signed-off-by` on every commit | `git log --format=%B -1 \| grep Signed-off-by` |
| `Vuln scan (PR diff)` | | `govulncheck` on changed Go | needs network, CI only |
| `Check for removed URLs` | | Sphinx build with `--fail-on-warning` (any new warning is red), on every PR | the `sphinx-build` below, compare warning counts |
| `Automatic doc checks` | | spelling and inclusive language (Vale), link check, when `docs/**` changed. Link check is known to be flaky on external hosts, a failure on URLs you did not touch is not yours | cannot run offline, see Docs below |
| `Tests` | many | Robot integration suites in LXD VMs against a built snap | not in the clinic, see the end |

`tox -e robot -- --test-suite <suite>` runs a Robot suite as CI does
(tox builds its venv from the bundle's wheels, so it works offline). Both
suites need Go, so full bundle only; on lite, use your track's individual
commands. It also runs the shell and Python suites, so iterate with the
individual commands and run the Robot runner once before you commit.

All inside `./clinic shell`; directory rule as in the cheat sheet.

## Go

Fast loop while editing, one package:

```
cd microceph
go test -count=1 ./<package>/...
```

Before committing:

```
cd microceph
make check-unit                      # every package, writes coverage.out
make check-static                    # golangci-lint
go vet ./...
cd ..
tox -e robot -- --test-suite static-checks    # check-static plus go vet, same as CI
```

Run one test by name:

```
cd microceph
go test -count=1 -run TestIsValidClusterName ./constants/...
```

### Testing a CLI change by hand

`make build` installs `microceph` and `microcephd` into `~/go/bin`. The CLI
binary runs on its own for anything that does not need the daemon:

```
cd microceph
make build
~/go/bin/microceph --help
~/go/bin/microceph log set-level --help          # group 3: see your new help text
~/go/bin/microceph --version
```

Anything that talks to the daemon (`cluster`, `disk`, `status`, `log
set-level` itself) needs a running MicroCeph. That is my VM or your
own `sudo snap install microceph` on a scratch machine, and it runs
the published snap, not your build. Testing a daemon-side change end to end
means building the snap (`snapcraft pack`, 20 to 30 minutes, needs LXD and
network), installing it with `--dangerous`, and connecting the plugs listed
in `HACKING.md`. Out of scope for the clinic.

### The coverage report

`make check-unit` writes `coverage.html` in the Go module directory
(`~/microceph-workshop/microceph/microceph/` on the host); it shows
whether your new test reaches the lines you changed. Both files are
gitignored.

## Shell (`snapcraft/commands/*`)

```
shellcheck -S warning snapcraft/commands/*
python3 -m pytest -q tests/scripts/test_osd_start.py tests/scripts/test_vaultlocker_reboot.py
tox -e robot -- --test-suite unit-tests       # the above plus the *.sh unit tests, as CI
```

`test_osd_start.py` runs the real `osd.start` with a fake `$SNAP` tree and
Python stand-ins for `ceph-osd`, `nc` and `sleep` on `PATH`. To add a case,
copy an existing test function and use the `wrapper` fixture. To debug a
failing case, run it alone with a fixed temp directory:

```
python3 -m pytest -x -k <name> --basetemp=/tmp/osd-start tests/scripts/test_osd_start.py
cat /tmp/osd-start/*/output
```

The fixture redirects the script's output to `<tmp_path>/output`, so `-s`
shows nothing from the script; read that file.

To run the script by hand outside pytest you need `SNAP`, `SNAP_DATA`,
`SNAP_COMMON` set and the fake binaries first on `PATH`, as the fixture
does. The test is quicker.

CI does not run shellcheck; reviewers do.

## Python (`tests/robot/resources/`)

```
python3 -m pytest -q tests/robot/resources                   # all three files, as CI runs them
python3 -m pytest -q tests/robot/resources -k <name>         # one test
python3 -m pytest -q tests/robot/resources -x -s -k <name>   # stop on first failure, show prints
```

Pure helpers (`@staticmethod`, no `self`, no `BuiltIn`) are tested directly.
Anything that calls `self._exec` is tested by monkeypatching `_exec` to
return an `ExecResult(rc, stdout, stderr)`. Several existing tests in the
file do this, grep for `monkeypatch.setattr(h, "_exec"`.

Robot keyword resolution across every suite, without LXD, at the repo root:

```
python3 -m robot --dryrun --output NONE --report NONE --log NONE tests/robot
```

Run this if you renamed, added or removed a keyword or a library method.
`AGENTS.md` asks for it before opening a PR to the harness.

## Docs (`docs/`)

```
sphinx-build -b html docs docs/_build/html
```

Pages land in `~/microceph-workshop/microceph/docs/_build/html/<path>.html`.
Look at the one you changed: Sphinx does not warn about a directive
missing its blank line, it renders it as text.

**CI builds with `--fail-on-warning`**, so any new warning is a red PR.
The offline build has about 8 baseline warnings, all about the missing
charm pages, so compare counts from clean builds. The recipe below writes
to fresh directories; if you reuse `docs/_build`, `rm -rf` it first, an
incremental rebuild under-reports. At the repo root:

```
git stash
sphinx-build -q -b html docs /tmp/docs-before 2>&1 | grep WARNING | sort > /tmp/warn-before; wc -l < /tmp/warn-before
git stash pop
sphinx-build -q -b html docs /tmp/docs-after 2>&1 | grep WARNING | sort > /tmp/warn-after; wc -l < /tmp/warn-after
```

Same number: fine. Higher: `diff /tmp/warn-before /tmp/warn-after` shows
the new one; fix it. Common causes: a heading underline shorter than the title, a
`:ref:` to a label that does not exist, a toctree entry for a page that is
already picked up by a glob, duplicate labels.

Spelling and Vale run only in CI (they download style rules). To lower
the odds of a spelling failure: US English, expand acronyms on first
use, put product names and commands in backticks, and add any term the
checker will not know to `docs/.custom_wordlist.txt` in alphabetical order.
`make linkcheck` also needs the network.

## CI YAML (`.github/`)

No local runner. Parse it:

```
python3 -c "import yaml,sys; [yaml.safe_load(open(f)) for f in sys.argv[1:]]; print('ok')" .github/workflows/checks.yml
```

Then read the diff with your group. The PR's own run is the test (held for
approval on a first PR).

## The whole CI unit gate in one command

```
tox -e robot -- --test-suite static-checks && tox -e robot -- --test-suite unit-tests
```

Expect several minutes the first time (Go compiles everything). It writes
`output.xml`, `log.html` and `report.html` in the repo root, gitignored.
Open `log.html` to see which step failed and its full output.

## Integration suites (not in the clinic)

These need LXD on the host, a built snap, and internet inside the VMs.

```
snapcraft pack -v                                         # at repo root, 20 to 30 min
sudo snap install lxd && sudo lxd init --auto
tox -e robot -- --snap-path ./microceph_*.snap --test-suite single-system-tests
```

`tests/robot/README.md` lists the suites and what each needs. A change to
daemon behaviour (anything under `microceph/ceph/` or `api/`) should name
in the PR which suite covers it, even if you could not run it.
