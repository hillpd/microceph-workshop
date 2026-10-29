# Group 3: #505 No clear documentation of the log level integers

https://github.com/canonical/microceph/issues/505

## The problem

`microceph log get-level` prints a bare integer and nothing says what it
means. The how-to says "the mapping from integer to string can be
consulted by querying the help for the `set-level` sub-command". There is
no `log` page in the CLI reference, and the only copy of the mapping is
the `Long` text of `set-level`, which lists `0 - PANIC` to `6 - TRACE.`
in uppercase and says nothing about case or aliases.

What the code accepts today: the daemon lowercases the input and calls
`logger.ParseLegacyLevels`, which takes `panic`, `fatal`, `error`,
`warning` (alias `warn`), `info`, `debug`, `trace` and the digits `0` to
`6`. So names are case-insensitive and `warn` works. `get-level` returns
the integer for the current level.

The how-to is also wrong about the default: it says the daemon runs at
DEBUG, the code defaults to info. A level set with `set-level` is written
to `log-config.json` in the daemon's data directory and survives a
restart, so the default only describes a fresh daemon.

## Where

- `microceph/cmd/microceph/log.go`: `cmdLogSetLevel.Command()` (line 28,
  mapping in `Long` at 32-41), `cmdLogGetLevel.Command()` (line 49, `Short`
  only, no `Long`).
- `microceph/api/microceph_configs.go:39-45` (set, `strings.ToLower`) and
  `:54-62` (get).
- `microceph/logger/logger.go`: `legacyLvlS2I` (line 202),
  `ParseLegacyLevels` (254), default `levelVar.Set(slog.LevelInfo)` (31).
- `docs/snap/how-to/change-log-level.rst`: default at line 9, the "consulted
  by querying the help" sentence at line 24.
- `docs/snap/reference/commands/`: one `.rst` per command, no `log.rst`;
  `index.rst` uses a `:glob:` toctree.
- CI gate: `Automatic doc checks` (documentation-checks) and
  `Check for removed URLs` (builds with `--fail-on-warning`) for the docs;
  the `Checks` workflow for the Go change.

## First job

Do a clean docs build, note the warning count, and confirm there is no
`log` reference page; then read the help text users see:

```
rm -rf docs/_build && sphinx-build -b html docs docs/_build/html
(cd microceph && go run ./cmd/microceph log get-level --help)
```

## Definition of done

- [ ] A `log` page in the CLI reference documents both subcommands and
      the integer to level table, including case-insensitivity and `warn`.
- [ ] The how-to links to that table instead of pointing at `--help`, and
      states the default level the code actually uses.
- [ ] `get-level --help` tells the user where the mapping is.
- [ ] Clean docs build with no new warnings against your first build;
      both pages render and the table is a table.
- [ ] Green: `(cd microceph && go test -count=1 ./cmd/microceph/...)`,
      `(cd microceph && make check-static)`; `gofmt` clean.
- [ ] US English; `git diff --check` prints nothing.
- [ ] The new page has an HTML meta description and a title that says
      what it is; the PR template checklist asks for both.
- [ ] Docs commit `docs: <summary>` with `Fixes #505`; a separate
      `fix: <summary>` commit for the CLI help with `Related: #505`.

## Watch out

- The page title ``log`` is 7 characters with its backticks; a 7-character
  `=======` underline is what `git diff --check` flags as a conflict
  marker.
- `index.rst` globs `*`; an explicit entry for the new page duplicates it.
- Level names written outside literals go through the spell checker
  (`docs/.custom_wordlist.txt`).
- Every page in `reference/commands/` uses `code-block`, while #868 says
  `code::`/`terminal::` is the house standard now.
- Adding a field to the `cobra.Command` literal re-aligns it; run `gofmt`.
- Question: should `get-level` print a human-readable form? Scripts may
  rely on the bare integer, so that is an interface change.
