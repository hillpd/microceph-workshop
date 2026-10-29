#!/usr/bin/env bash
# Readiness report. Two parts, because the toolchain may live in a container
# while git identity, the repo and the bundle live on the host:
#
#   preflight.sh host  [repo] [artifacts]   identity, repo, remotes, bundle presence
#   preflight.sh env   [repo] [artifacts]   toolchain, Go cache, warm build
#   preflight.sh all   [repo] [artifacts]   both (host environment)
#
# ./clinic preflight runs the host part here and the env part inside the
# environment, then prints one verdict. Exit 0 = READY, 1 = NOT READY.

set -uo pipefail
PART="${1:-all}"; shift || true
KIT="$(cd "$(dirname "$0")/.." && pwd)"
REPO="${1:-$KIT/microceph}"
ART="${2:-}"
if [ -z "$ART" ]; then
  for c in /artifacts "$(cat "$KIT/.clinic-artifacts" 2>/dev/null)" "$KIT/../microceph-artifacts" "$HOME/microceph-artifacts"; do
    [ -n "$c" ] && [ -f "$c/VERSIONS" ] && ART="$c" && break
  done
fi

PASS=0; FAIL=0; WARN=0
ok()   { PASS=$((PASS+1)); printf 'ok    %s\n' "$*"; }
bad()  { FAIL=$((FAIL+1)); printf 'FAIL  %s\n' "$*"; }
warn() { WARN=$((WARN+1)); printf 'warn  %s\n' "$*"; }

host_part() {
  echo "== git identity"
  name=$(git -C "$REPO" config --get user.name 2>/dev/null || git config --get user.name || true)
  email=$(git -C "$REPO" config --get user.email 2>/dev/null || git config --get user.email || true)
  [ -n "$name" ] && ok "user.name = $name" || bad "git user.name is unset (the DCO sign-off needs it)"
  [ -n "$email" ] && ok "user.email = $email" || bad "git user.email is unset (the DCO sign-off needs it)"
  case "$email" in
    *noreply.github.com) ok "noreply address: fine if that is what your GitHub account uses" ;;
    "") ;;
    *) warn "make sure $email is a verified address on your GitHub account, or the CLA check fails" ;;
  esac

  echo "== repository"
  if [ -d "$REPO/.git" ]; then
    ok "clone at $REPO"
    for r in bundle upstream; do
      git -C "$REPO" remote get-url "$r" >/dev/null 2>&1 && ok "remote $r = $(git -C "$REPO" remote get-url "$r")" || bad "remote $r missing (re-run prep.sh)"
    done
    git -C "$REPO" remote get-url origin >/dev/null 2>&1 && ok "remote origin = $(git -C "$REPO" remote get-url origin)" \
      || warn "no origin yet: git -C $REPO remote add origin <your fork>"

    git -C "$REPO" rev-parse --verify -q main >/dev/null && ok "branch main exists" || bad "no local main branch (re-run prep.sh)"
    if [ -n "$ART" ] && [ -f "$ART/PINNED_COMMIT" ]; then
      [ "$(git -C "$REPO" rev-parse main 2>/dev/null)" = "$(cat "$ART/PINNED_COMMIT")" ] \
        && ok "main is at the pinned commit" || warn "main is not at the pinned commit (fine if you rebased on purpose)"
    fi
    git -C "$REPO" diff --quiet 2>/dev/null && git -C "$REPO" diff --cached --quiet 2>/dev/null && ok "working tree clean" || warn "working tree has local changes"
  else
    bad "no clone at $REPO (re-run prep.sh)"
  fi

  echo "== bundle"
  if [ -n "$ART" ]; then
    ok "artifacts at $ART"
    for f in VERSIONS PINNED_COMMIT microceph.git wheels debs; do [ -e "$ART/$f" ] && ok "$f present" || bad "$f missing from bundle"; done
    [ -d "$ART/gomodcache/cache/download" ] && ok "Go module cache present (full bundle)" || warn "no Go module cache (lite bundle: docs, Python and CI groups only)"
  else
    bad "artifacts bundle not found (expected ~/microceph-artifacts or the path recorded by prep.sh)"
  fi
}

env_part() {
  echo "== toolchain"
  if [ ! -f "$HOME/.microceph-clinic.env" ]; then
    bad "environment not set up (./clinic deps)"; return
  fi
  # shellcheck disable=SC1091
  . "$HOME/.microceph-clinic.env"
  ok "env file present"
  HAVE_GO=0
  [ -n "$ART" ] || bad "artifacts bundle not visible from here (expected /artifacts or the path prep recorded)"
  if [ -n "$ART" ]; then
    # shellcheck disable=SC1091
    . "$ART/VERSIONS"
    if [ -d "$ART/gomodcache/cache/download" ]; then
      if command -v go >/dev/null; then
        HAVE_GO=1
        gv=$(go version | awk '{print $3}')
        [ "$gv" = "go$GO_VER" ] && ok "go $GO_VER ($(command -v go))" || bad "go is $gv, bundle expects go$GO_VER (which go: $(command -v go))"
        need=$(awk '/^go /{print $2}' "$REPO/microceph/go.mod" 2>/dev/null || true)
        if [ -n "$need" ]; then
          if [ "$(printf '%s\n%s\n' "$need" "${gv#go}" | sort -V | head -1)" = "$need" ]; then ok "go satisfies go.mod (go $need)"; else bad "go.mod needs go >= $need but the bundle ships $gv. The bundle was built wrong, tell the facilitator"; fi
        fi
        case "$(go env GOPROXY)" in file://*) ok "GOPROXY is the bundle" ;; *) bad "GOPROXY=$(go env GOPROXY), should be a file:// URL into the bundle" ;; esac
        command -v golangci-lint >/dev/null && ok "golangci-lint" || bad "golangci-lint missing"
        [ -f /usr/include/dqlite.h ] && ok "dqlite headers" || bad "dqlite headers missing"
      else
        bad "go not on PATH although the bundle has Go (./clinic deps)"
      fi
    else
      ok "lite bundle: Go checks skipped"
    fi
  fi
  for t in shellcheck sphinx-build pytest; do command -v "$t" >/dev/null && ok "$t" || bad "$t missing (./clinic deps)"; done

  echo "== warm cache"
  LOG="$KIT/.clinic-logs/preflight.log"; mkdir -p "$KIT/.clinic-logs"
  if [ "$HAVE_GO" = 1 ] && [ -d "$REPO/microceph" ]; then
    if ( cd "$REPO/microceph" && timeout 180 go test -count=1 ./common/... ) >"$LOG" 2>&1; then
      ok "go test ./common/... passes"
    else
      bad "go test ./common/... fails (or took over 3 minutes). Output in $LOG. Run ./clinic warm"
      tail -5 "$LOG" | sed 's/^/      /'
    fi
  fi
  [ -f "$REPO/docs/_build/html/index.html" ] && ok "docs built once" || warn "docs not built yet (./clinic docs)"
}

case "$PART" in
  host) host_part ;;
  env)  env_part ;;
  all)  host_part; env_part ;;
  *) echo "usage: preflight.sh host|env|all [repo] [artifacts]" >&2; exit 2 ;;
esac

echo
case "$PART" in
  all)
    if [ "$FAIL" -eq 0 ]; then echo "READY ($PASS ok, $WARN warnings)"; else echo "NOT READY ($FAIL failures, $WARN warnings)"; exit 1; fi ;;
  *)
    if [ "$FAIL" -eq 0 ]; then echo "$PART checks: all ok ($PASS ok, $WARN warnings)"; else echo "$PART checks: $FAIL FAILED ($WARN warnings)"; exit 1; fi ;;
esac
