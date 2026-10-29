# 6. Validate

Before every commit. These are CI's gates, minus the ones in 6.4.

## 6.1 The two CI gates (Go changes)

Go only. `make check-static` and `make check-unit` lint and test the Go
module; the shell, Python, docs and CI YAML groups run their 6.2 row
instead, plus 6.3's `unit-tests` suite if they have the full bundle.

```
cd microceph
make check-unit          # go test -cover ./...
make check-static        # golangci-lint (aborts if shellcheck is not installed)
cd ..
```

Both must exit 0. `check-unit` writes `coverage.out` and `coverage.html`,
both gitignored. `make check-unit` has no `-count=1`, so a second run can
serve cached results; `go test -count=1 ./...` (in `microceph/`) forces a
rerun. CI's `static-checks` suite also runs `go vet ./...`; the 6.3
command covers it, or run `(cd microceph && go vet ./...)` alone.

## 6.2 Track-specific

| Changed | Run | Must |
|---|---|---|
| `snapcraft/commands/*` | `shellcheck -S warning snapcraft/commands/osd.start` and `python3 -m pytest -q tests/scripts/test_osd_start.py tests/scripts/test_vaultlocker_reboot.py` | no new shellcheck findings (`snapcraft/commands/*` is red on `main`: `commands/common` has a pre-existing SC2148), pytest all passed |
| `tests/robot/resources/*.py` | `python3 -m pytest -q tests/robot/resources` | all passed |
| `docs/**` | `rm -rf docs/_build && sphinx-build -b html docs docs/_build/html` | exit 0, same warning count as a clean build before your change, your page renders correctly |
| `.github/**` | YAML parses, diff read aloud | no `permissions:` change |

## 6.3 Run CI's own runner once

At the repo root:

```
tox -e robot -- --test-suite static-checks && tox -e robot -- --test-suite unit-tests
```

Needs the full bundle; several minutes. Details in
[Testing locally](local-testing.md).

## 6.4 Things CI does that you cannot run here

- Docs spelling, inclusive-language and link checks (`Automatic doc
  checks`, only when `docs/**` changed). Avoid new terms, or add them to
  `docs/.custom_wordlist.txt`.
- `Vuln scan (PR diff)`: runs when `microceph/**/*.go`, `go.mod`, `go.sum`
  or `.github/actions/govulncheck/**` change, needs the network, and fails
  only on a vulnerability your change newly reaches.
- Robot integration suites in LXD VMs (`Tests`). They run on every PR
  once a maintainer approves workflows for a first-time contributor, and
  take a long time. Do not wait for them today.
- The DCO check, on the pushed commits; see [Commit](07-commit.md).

## 6.5 Self-review the diff

`git diff` against the Go house rules (import groups, no one-line
assign-and-test, doc comments, lowercase error strings); `git diff --check`
clean. CI YAML: both `checks.yml` jobs still identical in the steps you
touched, no `permissions:` change, no action pin changed.

## 6.6 Write the "After" line

In your scratch file, next to the "Before" from step 4:

```
After:  go test ./constants/... passes; "my-cluster" accepted,
        "-leading" and "trailing-" still rejected.
```

## Checkpoint

- [ ] `make check-unit` exit 0 (Go changes)
- [ ] `make check-static` exit 0 (Go changes)
- [ ] Track-specific check exit 0
- [ ] `git diff --check` prints nothing
- [ ] `git status` shows only files you meant to change
- [ ] "Before" and "After" lines written
