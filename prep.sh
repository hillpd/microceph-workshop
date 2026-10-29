#!/usr/bin/env bash
# Participant prep. Run it INSIDE a fresh ubuntu:24.04 LXD container that
# you launched yourself (see README). It refuses to run anywhere that is not
# a container unless you pass --on-this-machine. Safe to re-run: every step
# skips what is already done.
#
#   ~/microceph-artifacts/kit/prep.sh [--dest DIR] [--on-this-machine]
#
# What it does, all inside the machine it runs on:
#   1. verifies the bundle checksums and that the bundle has no files
#      beyond its manifest
#   2. copies this kit to ~/microceph-workshop
#   3. clones MicroCeph from the bundle mirror, remotes bundle and upstream
#      (add your fork as origin)
#   4. checks this is Ubuntu 24.04 amd64 (the container is)
#   5. installs the toolchain from the bundle: the manifest's debs with
#      sudo apt, Go under ~/.local/clinic/go, golangci-lint in ~/go/bin,
#      a Python venv in ~/clinic-venv, and ~/.microceph-clinic.env
#   6. compiles and tests everything once so later runs are fast
#   7. prints a readiness report
#
# Network: none, except apt fetching a dependency if the container image is
# newer than the bundle's debs. To undo everything: delete the container.

set -euo pipefail

DEST="$HOME/microceph-workshop"; ON_THIS_MACHINE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --dest) [ $# -ge 2 ] || { echo "--dest needs a directory" >&2; exit 2; }; DEST="$2"; shift 2 ;;
    --on-this-machine) ON_THIS_MACHINE=1; shift ;;
    -h|--help) sed -n 2,23p "$0"; exit 0 ;;
    *) echo "unknown argument: $1 (see --help)" >&2; exit 2 ;;
  esac
done

SRC_KIT="$(cd "$(dirname "$0")" && pwd)"
ART="$(cd "$SRC_KIT/.." && pwd)"
[ -f "$ART/VERSIONS" ] || { echo "this script must live inside the artifacts bundle (expected $ART/VERSIONS)" >&2; exit 2; }

step() { printf '\n==> %s\n' "$*"; }

step "1/7 bundle checksums"
# Each bundle kind ships its own complete manifest, so a truncated download
# of either kind is caught.
if [ -f "$ART/MANIFEST-full.sha256" ]; then MF=MANIFEST-full.sha256; KIND_MSG="full bundle (every track)"
elif [ -f "$ART/MANIFEST-lite.sha256" ]; then MF=MANIFEST-lite.sha256; KIND_MSG="lite bundle (docs, Python and CI groups, no Go)"
else echo "no MANIFEST-full.sha256 or MANIFEST-lite.sha256 in $ART. Not a clinic bundle, or an old one." >&2; exit 1; fi
( cd "$ART" && sha256sum --quiet -c "$MF" ) && echo "bundle ok" || { echo "checksum failure: the download is incomplete or corrupt. Re-download before continuing." >&2; exit 1; }
# The manifest must also be the complete list: setup installs every deb and
# wheel it finds, so an extra file would be used without a checksum.
EXTRA=$(cd "$ART" && comm -13 <(sed 's/^[0-9a-f]*  //' "$MF" | sort) <(find . -type f ! -name 'MANIFEST*.sha256' ! -name 'microceph-artifacts-*.tar.gz' ! -path './kit/.clinic-*' | sort) | grep -v '^\./kit/' || true)
[ -z "$EXTRA" ] || { echo "files in the bundle that are not in the manifest (refusing to use them):" >&2; echo "$EXTRA" >&2; exit 1; }
echo "$KIND_MSG"

step "2/7 kit -> $DEST"
mkdir -p "$DEST"
( cd "$SRC_KIT" && tar --exclude=microceph --exclude='.clinic-*' -cf - . ) | tar -C "$DEST" -xf -
chmod +x "$DEST/clinic" "$DEST"/scripts/*.sh "$DEST/prep.sh" 2>/dev/null || true
echo "$ART" > "$DEST/.clinic-artifacts"
echo "kit copied"

step "3/7 MicroCeph clone and remotes"
REPO="$DEST/microceph"
if [ ! -d "$REPO/.git" ]; then
  git clone -q "$ART/microceph.git" "$REPO"
  git -C "$REPO" remote rename origin bundle
fi
git -C "$REPO" remote get-url upstream >/dev/null 2>&1 || git -C "$REPO" remote add upstream https://github.com/canonical/microceph.git
git -C "$REPO" remote set-url bundle "$ART/microceph.git"
git -C "$REPO" fetch -q bundle
PIN="$(cat "$ART/PINNED_COMMIT")"
if ! git -C "$REPO" rev-parse --verify -q main >/dev/null; then
  git -C "$REPO" checkout -q -B main "$PIN"
elif [ "$(git -C "$REPO" branch --show-current)" = "main" ] && git -C "$REPO" diff --quiet && git -C "$REPO" diff --cached --quiet \
     && [ "$(git -C "$REPO" rev-parse main)" != "$PIN" ] && git -C "$REPO" merge-base --is-ancestor main "$PIN"; then
  echo "  moving main forward to the pinned commit"
  git -C "$REPO" checkout -q -B main "$PIN"
fi
git -C "$REPO" remote -v | sed 's/^/  /'
step "4/7 where am I"
VIRT=$(systemd-detect-virt --container 2>/dev/null || true)
if [ "$ON_THIS_MACHINE" = 0 ] && { [ -z "$VIRT" ] || [ "$VIRT" = none ]; }; then
  cat >&2 <<MSG
This does not look like a container (systemd-detect-virt --container: ${VIRT:-unknown}).
prep installs packages with sudo and is meant to run inside an ubuntu:24.04
LXD container that you launch yourself; see the README. If you really want
it on this machine, re-run with --on-this-machine.
MSG
  exit 2
fi
echo "container: ${VIRT:-no (--on-this-machine)}"
OS_ID=$(. /etc/os-release 2>/dev/null && echo "${ID:-}"); OS_VER=$(. /etc/os-release 2>/dev/null && echo "${VERSION_ID:-}")
if ! { [ "$OS_ID" = ubuntu ] && [ "$OS_VER" = 24.04 ] && [ "$(uname -m)" = x86_64 ]; }; then
  cat >&2 <<MSG
prep needs Ubuntu 24.04 on amd64 (the bundle's debs and wheels are built
for it). This machine is ${OS_ID:-unknown} ${OS_VER:-} $(uname -m).
Run it inside an ubuntu:24.04 LXD container, as the README shows.
MSG
  exit 2
fi

step "5/7 toolchain (from the bundle, needs sudo here)"
ARTIFACTS="$ART" "$DEST/scripts/run.sh" deps

step "6/7 warm the build (several minutes the first time)"
"$DEST/clinic" warm || echo "warm step had a failure, see above. The preflight below will show what."

step "7/7 readiness"
if "$DEST/clinic" preflight; then
  cat <<MSG

Prep complete. Before the clinic:
  - add your fork: git -C $DEST/microceph remote add origin <your fork>
  - read your group's brief in $DEST/groups/ and open its issue in a browser tab
  - print $DEST/guide/cheatsheet.md
At the clinic, everything is  cd $DEST && ./clinic <action>   (./clinic help)
MSG
else
  cat <<MSG

Each FAIL line above has an entry in $DEST/guide/troubleshooting.md.
Re-run this same prep command after fixing. If you are on a docs, Python or
CI issue and only the Go lines fail, you can still work: ./clinic docs,
./clinic harness-tests and ./clinic script-tests do not need Go. Tell me
either way, with this output attached.
Commands at the clinic:  cd $DEST && ./clinic <action>   (./clinic help)
MSG
  exit 1
fi
