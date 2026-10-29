# 4. Reproduce

The goal is one command whose output shows the problem.
Your brief calls this the "first job".

Several of the clinic issues are a year or more old and some are already
fixed. If yours is, the deliverable is the evidence on the issue (plus a
regression test if the brief has one), not a fix.

## 4.1 By track

**Go (groups 1 and 2).** Write the test from the brief into the package
it names, then run only that package:

```
cd microceph
go test -count=1 ./<package>/...        # e.g. ./constants/... or ./common/...
cd ..
```

Group 1: you want `--- FAIL` on `my-cluster` and `a-b-c`. Group 2:
the test is expected to PASS; the task there is to verify the issue is
already fixed and pin it with a regression test. Expect the first
`go test` to pause while it pulls modules from the bundle.

**Shell (group 4).** `osd.start` has a pytest suite that runs the real
script against fake `ceph-osd`, `nc` and `sleep` binaries:

```
python3 -m pytest -q tests/scripts/test_osd_start.py tests/scripts/test_vaultlocker_reboot.py
```

Its `wrapper` fixture shows how an OSD and a failure are simulated.
Reproduction is a new test case in that file that fails before your
change; the brief says what to simulate. If the LUKS path cannot be
reached from the fixture in the time you have, reproduction falls back to
reading the script and, if my encrypted-OSD VM is free, watching the
failure there.

**CI YAML (group 5).** Reproduction is finding the failing step and line
in the job logs linked from the issue. There is no local run.

**Python (group 6).** Run the existing helper tests, then do the brief's
first job (extend the stub in `test_vm_launch_failure.py` to put
`status: error` on stdout and assert it reaches the message) and watch it
fail:

```
python3 -m pytest -q tests/robot/resources
python3 -m pytest -q tests/robot/resources -k <your new test name>
```

**Docs (group 3).** Clean build:

```
rm -rf docs/_build && sphinx-build -b html docs docs/_build/html
```

Pages land in `docs/_build/html/<path>.html`. Group 3: confirm
`snap/reference/commands/log.html` does not exist, then run
`(cd microceph && go run ./cmd/microceph log get-level --help)` to see the
help text you will change; there is no test to write.

## 4.2 Write down what you saw

One line, for the PR description's "Before":

```
Before: go test ./constants/... fails TestIsValidClusterName on "my-cluster"
        (ClusterNameRegex rejects '-').
```

## 4.3 Expected noise

- offline docs build prints about 8 warnings, all about the missing charm
  pages; exit 0; see [troubleshooting](troubleshooting.md). Count warnings
  from a clean build (`rm -rf docs/_build` first); an incremental rebuild
  under-reports.
- `matplotlib is not installed, social cards will not be generated`. Harmless.
- Sphinx does not warn about a directive that is missing its blank line.
  It renders it as text. Build and look at the page.
- Go: do not commit `go.mod` or `go.sum` changes; the bundle cannot serve
  a new dependency.

## Checkpoint

- [ ] You have one command and its output that shows the problem, or
- [ ] You have shown the problem is already fixed and told me
- [ ] It is written in your scratch file as "Before:"
- [ ] You have not changed any non-test code yet
