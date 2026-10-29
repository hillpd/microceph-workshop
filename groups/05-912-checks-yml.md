# Group 5: #912 checks.yml: harden the apt install step and enable the Go module cache

https://github.com/canonical/microceph/issues/912

## The problem

Two unrelated flakes in the `Checks` workflow, each about 1 in 112 runs:

1. `apt-get update` exits 100 when `packages.microsoft.com` answers 403,
   although every Ubuntu and dqlite PPA index downloaded. The workflow
   never adds that source; it comes with the runner image. MicroCeph does
   not use it. The step has no retry.
2. `actions/setup-go@v5` looks for `go.sum` at the repo root, and ours is
   `microceph/go.sum`. Every run logs `Restore cache failed` and downloads
   all modules from `proxy.golang.org`, which once failed with a stream
   error. `GOPROXY` falls back to `direct` only on 404 or 410.

The issue proposes either removing the runner's Microsoft source or a
three-attempt apt loop, adding `cache-dependency-path` to every
`setup-go` step, and optionally a `go mod download` retry. It notes that
its guessed source file names are unchecked.

## Where

- `.github/workflows/checks.yml`: jobs `static-checks` and `unit-tests`,
  each with `Install dependencies` (lines 21-25 and 59-63) and
  `Install Go (1.27)` (27-30 and 65-68). The `preflight` job is the dqlite
  canary both `needs:`.
- `.github/actions/govulncheck/action.yml`: apt step (lines 38-50, already
  retries `apt-get install`) and `Install Go` (53-56, `go-version` from
  an input).
- `.github/workflows/vuln-scan-pr.yml` calls that action twice in one job,
  with `working-directory` `microceph` and `base/microceph`, and runs when
  the action changes.
- CI gate: the PR's own `Checks` run, plus `Vuln scan (PR diff)` if the
  action is touched.

## First job

Open the two failed job logs linked from the issue: the `Err:` line for
`packages.microsoft.com` with `403  Forbidden` in `Install dependencies`,
and `Restore cache failed` in `Install Go`. Then confirm the cause on main:
`grep -rn cache-dependency-path .github` finds nothing and
`ls go.sum microceph/go.sum` shows only the second.

## Definition of done

- [ ] A failing or 403ing Microsoft source can no longer fail
      `Install dependencies` in either `checks.yml` job or in the
      govulncheck action.
- [ ] Every `setup-go` step keys its cache on the right `go.sum`; in the
      action, the one under its `working-directory`.
- [ ] Both `checks.yml` jobs stay identical in these steps; `preflight`
      and `permissions:` untouched; `@v5` pin unchanged.
- [ ] Both files parse:
      `python3 -c "import yaml,sys; [yaml.safe_load(open(f)) for f in sys.argv[1:]]" .github/workflows/checks.yml .github/actions/govulncheck/action.yml`.
- [ ] On the PR: `Checks` green, `Post Install Go` logs `Cache saved` on
      the first run and a re-run logs `Cache restored`; `Vuln scan (PR diff)`
      green if the action changed.
- [ ] Commit title `ci: <summary>` with `Fixes #912` if both flakes are
      covered, `Related: #912` if only one.

## Watch out

- On the 24.04 runner the source is `/etc/apt/sources.list.d/microsoft-prod.list`;
  the issue's `.sources` guess is not what is there.
- A literal `microceph/go.sum` in the action would key the base-branch
  scan on the head's `go.sum`.
- The `setup-go` main branch README documents a newer major; read the v5
  README. v6 moved the default key file to `go.mod`.
- The first run of a PR can only save the cache; a cache is scoped to the
  PR, and main gets its own after merge.
- Both jobs and the vuln scan compute the same cache key; the losers log
  a warning on save.
- Question: remove the source, retry the apt step, or both?
