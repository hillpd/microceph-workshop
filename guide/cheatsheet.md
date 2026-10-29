# Cheat sheet

Everything runs inside your `microceph-clinic` container:

```
cd ~/microceph-workshop
./clinic shell        # opens at the repo root, toolchain on PATH
```

| Plumbing | Command |
|---|---|
| readiness report | `./clinic preflight` |
| a shell with the toolchain on PATH | `./clinic shell`, repo root at `~/microceph-workshop/microceph` |
| reinstall the toolchain from the bundle | `./clinic deps` |

## Commands

Run these in `./clinic shell`. **Dir** is where: `microceph/` is the Go
module under the repo root, `.` is the repo root itself.

| Task | Dir | Command | Optional shortcut |
|---|---|---|---|
| all unit tests | `microceph/` | `make check-unit` | `./clinic unit` |
| one package | `microceph/` | `go test -count=1 ./common/...` | `./clinic unit common` |
| one test | `microceph/` | `go test -count=1 -run TestName ./constants/...` | |
| lint | `microceph/` | `make check-static` | `./clinic lint` |
| go vet | `microceph/` | `go vet ./...` | `./clinic vet` |
| build binaries | `microceph/` | `make build` (binaries in `~/go/bin`) | `./clinic build` |
| docs | `.` | `sphinx-build -b html docs docs/_build/html` | `./clinic docs` |
| shell scripts | `.` | `shellcheck -S warning -e SC2148 snapcraft/commands/*` (SC2148 excluded: `commands/common` is sourced and has no shebang) | `./clinic shellcheck` |
| script tests | `.` | `python3 -m pytest -q tests/scripts/test_osd_start.py tests/scripts/test_vaultlocker_reboot.py` | `./clinic script-tests` |
| harness tests | `.` | `python3 -m pytest -q tests/robot/resources [-k name]` | `./clinic harness-tests` |
| robot keywords resolve | `.` | `python3 -m robot --dryrun --output NONE --report NONE --log NONE tests/robot` | `./clinic dryrun` |
| exactly what CI runs | `.` | `tox -e robot -- --test-suite static-checks` then `--test-suite unit-tests` | `./clinic ci-local` |

Or run Go commands from the repo root as
`(cd microceph && make check-unit)`. The shortcuts run from
`~/microceph-workshop` on the host and print the real command before
running it. `./clinic help` lists them.

## Git (on the host, in `~/microceph-workshop/microceph`)

```
git checkout -b fix-NNN main
git add <file>
git commit -s
git push -u origin fix-NNN
git commit --amend -s && git push --force-with-lease origin fix-NNN   # after review
git fetch upstream && git rebase upstream/main                         # if main moved
git bundle create ~/fix-NNN.bundle main..fix-NNN                       # no GitHub? hand this file to me
```

## Commit message

```
<type>: <imperative summary, under 72 chars>

Why it was wrong and what this does. ASCII only.

Fixes #NNN
```

Types the history uses: `fix: feat: docs: test: ci: snap: chore: refactor:`.
`Related: #NNN` instead of `Fixes` when the PR does only part of the issue.
Add `Assisted-by: <tool>:<model>` above your sign-off if an AI tool helped
(`Assisted-by: Claude Code:<model>`, the space stays); no other bot
trailers such as `Co-Authored-By`.

## Go house rules

- imports: stdlib, blank, third party, blank, `github.com/canonical/microceph/...`
- `err := f()` newline `if err != nil`, never on one line
- doc comment on every exported name, no blank line before the declaration
- injectable function vars end in `Func`
- testify, table tests

## Docs house rules

- reST. Blank line before and after directives.
- Diataxis: tutorial teaches, how-to gives steps, reference describes, explanation discusses
- US English. New terms into `docs/.custom_wordlist.txt`, alphabetical
- CI fails on any new Sphinx warning (`Check for removed URLs` builds with `--fail-on-warning`). Compare warning counts before and after, from clean builds (`rm -rf docs/_build` first).

## Goals, in order

1. On branch `fix-NNN`.
2. Able to show the problem.
3. Green locally.
4. Committed and pushed (or bundled), PR open.

## Help

Every group has a Go expert, and there are several Ceph SMEs in the room,
plus me. Talk it through in your group, ask questions early and often;
nobody is expected to know MicroCeph going in. Still stuck:
[troubleshooting](troubleshooting.md).
