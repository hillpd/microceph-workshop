# Troubleshooting

## Environment

**`go: go.mod requires go >= 1.27.0 (running go 1.24.x; GOTOOLCHAIN=local)`**
You are running `go` outside `./clinic shell`, with a different Go first on
PATH. Open `./clinic shell` and run it there. Inside the shell `which go`
must print `~/.local/clinic/go/bin/go`. If it does and the version is still
wrong, `deps` did not install the bundle's Go: `./clinic preflight` shows
it, and `./clinic deps` re-runs the install.

**Go error naming a module and `file:///.../gomodcache/cache/download`**, or **`missing go.sum entry`**
A module is not in the bundle's download cache. If you added a
dependency, remove it; if not, the bundle is incomplete for this package,
tell me. (On a lite bundle `GOPROXY=off` and the message is
`module lookup disabled by GOPROXY=off`: Go groups are not available
on lite.)

**`make check-static` fails with a module lookup error mentioning golangci-lint**
`golangci-lint` is not on PATH, so the Makefile tried to `go install` it,
which the bundle proxy cannot serve (the linter's modules are not shipped,
only its binary). If `./clinic preflight` says golangci-lint is missing,
run `./clinic deps` again.

**preflight: `dqlite headers missing`**
The `libdqlite*-dev` deb from the bundle did not install. Same cause and
fix as `MISSING: shellcheck` below: re-run `./clinic deps`, and if it still
fails, run the apt command there and read the error.

**`./clinic deps` prints `MISSING: shellcheck`** (or another tool)
The deb did not install. Run
`sudo apt-get install ~/microceph-artifacts/debs/*.deb` and read the
error. Usually a dependency the bundle did not include, which apt fetches
from the archive. Otherwise, ask me.

**prep says `This does not look like a container`** or **`prep needs Ubuntu 24.04 on amd64`**
You ran it outside the container, or launched a different image. Launch
`ubuntu:24.04` with LXD as in [step 1.2](01-prep.md) and run prep inside it.

**`sphinx-build: command not found`**
Run `./clinic deps` again, it installs the docs requirements from the
bundle's wheelhouse.

**`sphinx-build -b html docs docs/_build/html` takes two minutes**
Intersphinx tries to fetch five remote inventories and waits for each to
time out on a captive or half-working network. With no DNS it fails fast.

**First `go test` takes minutes**
It is compiling cgo against dqlite; the second run takes seconds. Prep
([step 1.3](01-prep.md)) compiles everything once beforehand.

**`go.mod needs go >= X but the bundle ships Y`** in preflight
The bundle was built against a different commit than the one it ships. Not
fixable on your side. Tell me, a new bundle is needed.

## Tests and lint

**Reviewer asks for import grouping**
Three groups: stdlib, third party, microceph. Blank line between. Neither
`gofmt` nor the linter enforces this, reviewers do. `gofmt` sorts inside a
group but will not move a line between groups.

**`Please install shellcheck` from `make check-static`**
`shellcheck` is not on PATH. If `./clinic preflight` says shellcheck is
missing, see `MISSING:` above.

**`undefined label: 'charm-get-started'` from the docs build**
Expected offline. The charm docs are pulled in by a CI workflow. About 8
of these from a clean build (`rm -rf docs/_build` first). Ignore.

**docs build fails with `Permission denied` on `latex_elements_template.txt`**
The venv is not writable by you: `canonical_sphinx` opens that file
read-write inside the venv. Make `~/clinic-venv` yours
(`sudo chown -R $USER ~/clinic-venv`) or rerun `./clinic deps` as
yourself, not with `sudo`.

**`inventory for external cross-reference not found`**
Expected offline. Intersphinx cannot fetch other projects' indexes. Ignore.

**`Git clone too shallow` from the docs build**
Your clone is shallow. The bundle mirror is not, so you cloned from
somewhere else. Harmless for the build.

**pytest: `ModuleNotFoundError: No module named 'robot'`**
Wrong Python. Run it as `python3 -m pytest -q tests/robot/resources`, which uses the clinic venv.

## Git

**DCO check fails on the PR but the commit has a sign-off**
Name or email in the sign-off differ from the commit author, or the name
is not a real name. Fix identity, `git commit --amend --reset-author -s`,
force-push with lease.

**CLA check fails**
The email on the commit is not one attached to a GitHub account that has
signed the CLA. Common cause: GitHub's "keep my email private" setting,
so the account's only verified address is the `noreply.github.com` one.
Either commit with that address, or add and verify your real address on
GitHub. Then `git commit --amend --reset-author -s` and force-push with
lease.

**PR shows "workflows awaiting approval" and nothing runs**
First PR from a fork. A maintainer has to approve the run. Tell me and
carry on.

**`git push origin` hangs or fails**
No GitHub. Commit, `git bundle create ~/fix-NNN.bundle main..fix-NNN`, hand
the file to me, finish when you have a connection.

**Accidentally committed `coverage.out` or `go.sum` changes**
`git rm --cached coverage.out` (it should be ignored already) or
`git checkout main -- microceph/go.sum`, then `git commit --amend -s`.

## Process

**Someone else has a PR for my issue**
Stop. Tell me. I'll find you another issue.

**The issue turns out to be already fixed**
Add the regression test if the brief gives one, and comment on the issue
with the evidence. Group 2's brief is written for exactly this.

**The review block is starting and I am not done**
Commit what you have with a message that says what works and what does
not, push, and move to the review block. Finish it in the week after.
