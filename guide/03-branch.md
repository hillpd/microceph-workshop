# 3. Branch

## 3.1 Start from main

Your `main` is the bundle's pinned commit, which is recent upstream `main`.
Branch from it as it is:

```
cd ~/microceph-workshop/microceph
git checkout -b fix-NNN main
```

Do not fetch and merge `upstream/main` yet, even if the network is up: Go
can only fetch modules from the bundle, which matches the pinned commit,
so a refreshed `main` that added a dependency will not build. Rebase later
if main has moved ([step 9.3](09-after-the-clinic.md)).

`fix-NNN`, NNN the issue number, one branch per issue; the review block is
sorted by it.

## 3.2 The clinic shell

The clone is inside the container at `~/microceph-workshop/microceph`.
Run checks from the clinic shell, which has the toolchain on `PATH`:

```
cd ~/microceph-workshop
./clinic shell
```

The commands on each page are the project's own (`make check-unit`,
`go test`, `sphinx-build`, `pytest`), as CI runs them.

The shell opens at the repo root, `~/microceph-workshop/microceph`. One
rule for directories:

- Go commands (`go test`, `go vet`, `go build`, `make ...`) run in the Go
  module directory, `microceph/` under the repo root. Code blocks start
  with `cd microceph`, inline commands are written as
  `(cd microceph && make check-unit)`.
- Everything else (`sphinx-build`, `python3 -m pytest`, `shellcheck`,
  `tox -e robot`, `git`) runs at the repo root.

Go has no network access in the shell: `GOPROXY` is a `file://` URL into
the bundle. If a Go command fails with a lookup error naming a module path
and `file:///...`, the bundle is missing a module. Tell me.

## Checkpoint

- [ ] `git branch --show-current` prints `fix-NNN`
- [ ] `./clinic preflight` still says `READY`
