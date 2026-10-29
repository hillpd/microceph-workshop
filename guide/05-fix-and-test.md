# 5. Fix and test

Smallest change that makes the reproduction pass.
The brief has a suggested approach, use it unless the issue thread says
otherwise. One issue per PR; no drive-by renames, reformatting or
refactors.

## 5.1 Go

House rules that reviewers will send back (`CONTRIBUTING.md`, `AGENTS.md`):

Imports in three groups, blank line between, each alphabetical. Neither
`gofmt` nor the linter creates or checks the groups; reviewers do. Do not
reorder imports in existing files that predate the rule unless you are
adding one:

```go
import (
	"fmt"
	"strings"

	"github.com/stretchr/testify/assert"

	"github.com/canonical/microceph/microceph/common"
)
```

Never assign and test on one line:

```go
// yes
err := doStuff()
if err != nil {
	return err
}

// no
if err := doStuff(); err != nil {
	return err
}
```

Every exported name gets a doc comment starting with the name, directly
above it, no blank line between.

Package-level function variables that exist so tests can swap them end in
`Func` (`getMonitorCountFunc`).

Tests use testify, table-driven, in the style of the nearest existing
`_test.go`.

Run after each change, in the Go module directory:

```
cd microceph
go test -count=1 ./<package>/...
```

## 5.2 Shell (`snapcraft/commands/*`)

These scripts run as snap services under `set -eu`. Read `AGENTS.md`
"Atomic file writes" if you touch config. Keep error lines greppable, they
end up in `journalctl`. Every change gets both:

```
shellcheck -S warning snapcraft/commands/osd.start
python3 -m pytest -q tests/scripts/test_osd_start.py tests/scripts/test_vaultlocker_reboot.py
```

The pytest files exercise the real scripts; CI runs them in the
`unit-tests` suite.

`shellcheck` must report no new findings at warning level on the file you
touched (`snapcraft/commands/*` as a whole is red on `main`: `commands/common`
has a pre-existing SC2148, not yours to fix here). CI does not run it,
reviewers do. Fix the warning, do not add a disable comment unless the
line directly above already has one for the same reason.

## 5.3 Python (`tests/robot/resources/`)

Read the "Library rules" in `AGENTS.md` before editing
`microceph_harness.py`; the group 6 brief lists the ones that bite.

Add a test for every pure helper in `test_harness_helpers.py`, copying the
`_Res(rc, stdout, stderr)` parametrised pattern already there.

```
python3 -m pytest -q tests/robot/resources
```

## 5.4 Docs (`docs/`)

reStructuredText, not Markdown. Diataxis: a how-to gives steps, a
reference page describes, a tutorial teaches, an explanation discusses. Do
not mix. US English. A blank line before and after every directive.
Headings use the underline character the surrounding file uses.

```
sphinx-build -b html docs docs/_build/html
```

Check the rendered page, not just the exit code (see the blank-line note
in [step 4.3](04-reproduce.md)). Unknown technical terms that the CI spell
check will reject go in `docs/.custom_wordlist.txt` in alphabetical order.

## 5.5 CI YAML (`.github/`)

No local run. Parse it:

```
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/checks.yml'))"
```

Review the diff with your group; the PR's own CI run is the test. Do not
change `permissions:` blocks.

## Checkpoint

- [ ] The reproduction from step 4 now passes (or the page now renders)
- [ ] The track-specific check above is green
- [ ] `git diff --stat` touches only files the issue is about
- [ ] No `go.sum` or `go.mod` changes
