#!/usr/bin/env bash
# Single implementation of every clinic action. Called three ways:
#   ./clinic calls scripts/run.sh <action>, or call it directly
#
# Layout assumed: this kit at $KIT (the directory above scripts/), the
# MicroCeph clone at $KIT/microceph, the artifacts bundle at $ARTIFACTS
# (default /artifacts, or $KIT/../microceph-artifacts on a host).
#
# Usage: run.sh <action> [args...]      run.sh help

set -euo pipefail
KIT="$(cd "$(dirname "$0")/.." && pwd)"
REPO="$KIT/microceph"
ARTIFACTS="${ARTIFACTS:-}"
if [ -z "$ARTIFACTS" ]; then
  for c in /artifacts "$(cat "$KIT/.clinic-artifacts" 2>/dev/null)" "$KIT/../microceph-artifacts" "$HOME/microceph-artifacts"; do
    if [ -n "$c" ] && [ -f "$c/VERSIONS" ]; then ARTIFACTS="$(cd "$c" && pwd)"; break; fi
  done
fi
LOGDIR="$KIT/.clinic-logs"; mkdir -p "$LOGDIR"   # under the kit, so the host sees it from any environment
SPHINX_OPTS=""
ENVFILE="$HOME/.microceph-clinic.env"

action="${1:-help}"; shift || true

need_env() {
  if [ ! -f "$ENVFILE" ]; then
    echo "environment not set up. Run: run.sh deps" >&2; exit 2
  fi
  # shellcheck disable=SC1090
  . "$ENVFILE"
}
need_repo() {
  [ -d "$REPO/microceph" ] || { echo "no MicroCeph clone at $REPO. Run prep.sh first." >&2; exit 2; }
}
# Print the real command, with its directory relative to the repo root, then run it.
# Actions are shortcuts; the guide teaches the commands, so show them.
x() {
  local rel="${PWD#"$REPO"}"; rel="${rel#/}"
  if [ -n "$rel" ]; then echo "+ (cd $rel && $*)"; else echo "+ $*"; fi
  "$@"
}

case "$action" in
  help|-h|--help)
    cat <<EOF
Actions (run as ./clinic <action> from the kit directory).
The check actions are shortcuts: each prints the real command before running it.
The guide teaches those commands, run them yourself in ./clinic shell.
  help                     this list
  preflight                readiness report (host checks, then toolchain checks in the environment)
  shell                    a shell inside the environment at the repo root, toolchain on PATH
  deps                     install toolchain from the artifacts bundle (one-time, needs sudo)
  unit [pkg ...]           make check-unit, or go test for the named packages (e.g. unit common api)
  lint                     make check-static
  vet                      go vet ./...
  build                    make build (binaries in ~/go/bin)
  docs                     sphinx-build the docs to docs/_build/html
  shellcheck               shellcheck -S warning snapcraft/commands/*
  script-tests [args]      pytest for tests/scripts/test_osd_start.py and test_vaultlocker_reboot.py
  harness-tests [args]     pytest for tests/robot/resources (all three files, as CI)
  unit-py                  CI's unit-tests suite minus Go: shell tests, every pytest file, the orchestrator import test
  dryrun                   robot --dryrun over every suite (keyword resolution, no LXD)
  ci-local [suite]         CI's own runner, tox -e robot: static-checks, unit-tests, or both
  warm                     compile and run everything once so the venue runs are fast
  preflight-env            toolchain half of preflight on its own (used by ./clinic preflight)
EOF
    ;;
  deps)
    [ -n "$ARTIFACTS" ] || { echo "artifacts bundle not found (set ARTIFACTS=/path)" >&2; exit 2; }
    "$KIT/scripts/setup-env.sh" "$ARTIFACTS"
    "$KIT/scripts/docs-deps.sh" "$REPO"
    ;;
  unit)
    need_env; need_repo; cd "$REPO/microceph"
    if [ $# -eq 0 ]; then x make check-unit
    else
      pkgs=(); for p in "$@"; do pkgs+=("./$p/..."); done
      x go test -count=1 "${pkgs[@]}"
    fi ;;
  lint)   need_env; need_repo; cd "$REPO/microceph"; x make check-static ;;
  vet)    need_env; need_repo; cd "$REPO/microceph"; x go vet ./... && echo "go vet ok" ;;
  build)  need_env; need_repo; cd "$REPO/microceph"; x make build; ls -l "$HOME/go/bin/microceph" "$HOME/go/bin/microcephd" ;;
  docs)   need_env; need_repo; cd "$REPO"; x sphinx-build $SPHINX_OPTS -b html docs docs/_build/html; echo "open: $REPO/docs/_build/html/index.html" ;;
  # SC2148 (no shebang) is excluded: snapcraft/commands/common is sourced, not run, and trips it on main.
  shellcheck) need_env; need_repo; cd "$REPO"; echo "+ shellcheck -S warning -e SC2148 snapcraft/commands/*"; shellcheck -S warning -e SC2148 snapcraft/commands/* && echo "shellcheck: no findings" ;;
  script-tests)  need_env; need_repo; cd "$REPO"; x python3 -m pytest -q tests/scripts/test_osd_start.py tests/scripts/test_vaultlocker_reboot.py "$@" ;;
  harness-tests) need_env; need_repo; cd "$REPO"; x python3 -m pytest -q tests/robot/resources "$@" ;;
  unit-py)
    # Everything CI's unit-tests suite runs apart from Go (unit_tests.robot). Works on the lite bundle.
    need_env; need_repo; cd "$REPO"
    x bash tests/scripts/test_adoptutils.sh
    x python3 -m pytest -q tests/robot/resources tests/scripts/test_osd_start.py tests/scripts/test_vaultlocker_reboot.py
    x python3 -m pytest -q microceph-orch/tests/test_module_import.py ;;
  dryrun) need_env; need_repo; cd "$REPO"; x python3 -m robot --dryrun --output NONE --report NONE --log NONE tests/robot ;;
  ci-local)
    # CI's exact runner (checks.yml). tox builds its venv from the bundle's
    # wheels: PIP_NO_INDEX and PIP_FIND_LINKS come from the env file.
    need_env; need_repo; cd "$REPO"
    if [ $# -eq 0 ]; then
      x tox -e robot -- --test-suite static-checks --console dotted
      x tox -e robot -- --test-suite unit-tests --console dotted
    else
      x tox -e robot -- --test-suite "$1" --console dotted
    fi ;;
  warm)
    need_env; need_repo
    echo "==> compiling and testing everything once (several minutes the first time). Logs: $LOGDIR"
    rc=0
    if command -v go >/dev/null && [ -d "$ARTIFACTS/gomodcache/cache/download" ]; then
      ( cd "$REPO/microceph" && make check-unit ) >"$LOGDIR/warm-unit.log" 2>&1 && echo "go tests: ok" || { echo "go tests: FAILED, see $LOGDIR/warm-unit.log"; tail -3 "$LOGDIR/warm-unit.log" | sed 's/^/    /'; rc=1; }
      ( cd "$REPO/microceph" && make check-static ) >"$LOGDIR/warm-lint.log" 2>&1 && echo "lint: ok" || { echo "lint: FAILED, see $LOGDIR/warm-lint.log"; tail -3 "$LOGDIR/warm-lint.log" | sed 's/^/    /'; rc=1; }
    else
      echo "go: skipped (lite bundle)"
    fi
    ( cd "$REPO" && sphinx-build -q $SPHINX_OPTS -b html docs docs/_build/html -w docs/_build/warnings.txt ) >"$LOGDIR/warm-docs.log" 2>&1 && echo "docs: ok ($(grep -c WARNING "$REPO/docs/_build/warnings.txt" 2>/dev/null || true) expected offline warnings)" || { echo "docs: FAILED, see $LOGDIR/warm-docs.log"; rc=1; }
    ( cd "$REPO" && bash tests/scripts/test_adoptutils.sh && python3 -m pytest -q tests/robot/resources tests/scripts/test_osd_start.py tests/scripts/test_vaultlocker_reboot.py && python3 -m pytest -q microceph-orch/tests/test_module_import.py ) >"$LOGDIR/warm-pytest.log" 2>&1 && echo "python and shell unit tests: ok" || { echo "python/shell unit tests: FAILED, see $LOGDIR/warm-pytest.log"; rc=1; }
    [ "$rc" = 0 ] && echo "warm. Venue runs will be fast." || echo "warm finished with failures."
    exit "$rc"
    ;;
  preflight-env) "$KIT/scripts/preflight.sh" env "$REPO" "$ARTIFACTS" ;;
  preflight)     "$KIT/scripts/preflight.sh" all "$REPO" "$ARTIFACTS" ;;
  *) echo "unknown action: $action (try: run.sh help)" >&2; exit 2 ;;
esac
