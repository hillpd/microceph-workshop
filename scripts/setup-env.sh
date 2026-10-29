#!/usr/bin/env bash
# Install everything the clinic needs from the offline artifacts bundle.
# Runs where prep.sh runs: inside the attendee's ubuntu:24.04 container.
# Needs sudo. No network. Safe to re-run.
#
# The Go module cache is NOT copied. Go is pointed at the bundle's download
# cache as a file:// proxy, so modules are fetched from the bundle on first
# use into the user's own cache. Read-only bundle mounts are fine.
#
# Usage: scripts/setup-env.sh <artifacts-dir>

set -euo pipefail
ART="$(cd "${1:?artifacts dir}" && pwd)"
# shellcheck disable=SC1091
. "$ART/VERSIONS"

echo "==> debs (the ones listed in the bundle manifest)"
MF=$(ls "$ART"/MANIFEST-*.sha256 | head -1)
mapfile -t DEBS < <(sed 's/^[0-9a-f]*  //' "$MF" | grep '^\./debs/.*\.deb$' | sed "s|^\./|$ART/|")
[ "${#DEBS[@]}" -gt 0 ] || { echo "no debs listed in $MF" >&2; exit 1; }
APTLOG="$HOME/.clinic-apt.log"
# The log is ours, not root's: the redirects are meant to run as the user.
# shellcheck disable=SC2024
if ! sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${DEBS[@]}" >"$APTLOG" 2>&1; then
  # The container image can be newer than the bundle's debs; let apt fetch
  # the few dependencies it is missing, then try again.
  echo "apt needs something the bundle does not have; refreshing the package index and retrying (log: $APTLOG)"
  # shellcheck disable=SC2024
  sudo apt-get update -qq >>"$APTLOG" 2>&1 || true
  # shellcheck disable=SC2024
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${DEBS[@]}" >>"$APTLOG" 2>&1 || { tail -20 "$APTLOG" >&2; exit 1; }
fi
echo "debs ok"

# Go is installed under the user's home, never over a system Go.
GOROOT_CLINIC="$HOME/.local/clinic/go"
if [ -d "$ART/go" ] && ls "$ART"/go/go*.tar.gz >/dev/null 2>&1; then
  echo "==> Go $GO_VER -> $GOROOT_CLINIC"
  if [ ! -x "$GOROOT_CLINIC/bin/go" ] || [ "$("$GOROOT_CLINIC/bin/go" version | awk '{print $3}')" != "go$GO_VER" ]; then
    rm -rf "$GOROOT_CLINIC"
    mkdir -p "$(dirname "$GOROOT_CLINIC")"
    tar -C "$(dirname "$GOROOT_CLINIC")" -xzf "$ART/go/go${GO_VER}.linux-${ARCH}.tar.gz"
  fi
  mkdir -p "$HOME/go/bin"
  cmp -s "$ART/bin/golangci-lint" "$HOME/go/bin/golangci-lint" 2>/dev/null || install -m 0755 "$ART/bin/golangci-lint" "$HOME/go/bin/golangci-lint"
  GOPROXY_VALUE="file://$ART/gomodcache/cache/download"
else
  echo "==> no Go in this bundle (lite bundle): Go work unavailable here"
  GOPROXY_VALUE="off"
fi

echo "==> Python venv (pytest, robotframework, tox, docs tooling)"
# tox is CI's runner (checks.yml: tox -e robot -- --test-suite <suite>). It
# builds its own venv from the bundle's wheels through PIP_NO_INDEX and
# PIP_FIND_LINKS below, so ./clinic ci-local runs exactly what CI runs.
if [ ! -x "$HOME/clinic-venv/bin/pytest" ] || [ ! -x "$HOME/clinic-venv/bin/tox" ]; then
  python3 -m venv "$HOME/clinic-venv"
  "$HOME/clinic-venv/bin/pip" install -q --no-index --find-links "$ART/wheels" pip wheel setuptools
  "$HOME/clinic-venv/bin/pip" install -q --no-index --find-links "$ART/wheels" robotframework pytest tox
fi

# Not written to .profile or .bashrc on purpose: this must not change how Go
# behaves on the machine outside the clinic. run.sh and ./clinic source it.
ENVFILE="$HOME/.microceph-clinic.env"
cat > "$ENVFILE" <<EOF
# MicroCeph clinic environment. Sourced by scripts/run.sh. For a manual shell: . ~/.microceph-clinic.env
export PATH="$GOROOT_CLINIC/bin:\$HOME/go/bin:\$HOME/clinic-venv/bin:\$PATH"
export GOTOOLCHAIN=local
export GOPROXY="$GOPROXY_VALUE"
export GOSUMDB=off
export PIP_NO_INDEX=1
export PIP_FIND_LINKS="$ART/wheels"
export VIRTUALENV_NO_PERIODIC_UPDATE=1
# tox passes PIP_* through by default but not the Go settings; without this
# tox -e robot would try proxy.golang.org for anything not yet cached.
export TOX_OVERRIDE="testenv.pass_env+=GOPROXY,GOSUMDB,GOTOOLCHAIN,GOFLAGS"
EOF

# shellcheck disable=SC1090
. "$ENVFILE"
echo "==> installed:"
for tool in go golangci-lint shellcheck python3 pytest tox; do
  if [ "$GOPROXY_VALUE" = off ] && { [ "$tool" = go ] || [ "$tool" = golangci-lint ]; }; then
    echo "$tool: not in this bundle (lite)"; continue
  fi
  if command -v "$tool" >/dev/null; then
    case $tool in
      go) go version ;;
      golangci-lint) golangci-lint version 2>&1 | head -1 ;;
      shellcheck) shellcheck --version | sed -n 2p ;;
      python3) python3 --version ;;
      pytest) pytest --version 2>&1 | head -1 ;;
      tox) echo "tox $(tox --version 2>/dev/null | head -1)" ;;
    esac
  else
    echo "MISSING: $tool"
  fi
done
echo "==> setup complete"
