#!/usr/bin/env bash
# Install the docs build requirements from the offline wheelhouse into the
# clinic venv, then build the docs once. Run after setup-env.sh.
#
# Usage: scripts/docs-deps.sh <path-to-microceph-checkout>

set -euo pipefail
REPO="${1:?microceph checkout}"
if [ ! -f "$REPO/docs/requirements.txt" ]; then
  echo "docs-deps: no checkout at $REPO yet, skipping (run again after cloning)"
  exit 0
fi
REPO="$(cd "$REPO" && pwd)"
# shellcheck disable=SC1091
. "$HOME/.microceph-clinic.env"

pip install -q -r "$REPO/docs/requirements.txt"
cd "$REPO"
# Offline, Sphinx warns about the charm docs (imported by a CI workflow, not
# in the repo) and about intersphinx inventories it cannot fetch. About 45
# warnings on a clean build, about a dozen on a rebuild. They go to
# docs/_build/warnings.txt so prep output stays readable. ./clinic docs
# shows them in full.
mkdir -p docs/_build
sphinx-build -q -b html docs docs/_build/html -w docs/_build/warnings.txt >/dev/null 2>&1 || true
n=$(grep -c WARNING docs/_build/warnings.txt 2>/dev/null || true)
if [ -f docs/_build/html/index.html ]; then
  echo "docs built ($n warnings, expected offline, see docs/_build/warnings.txt). Rebuild with: ./clinic docs"
else
  echo "docs build FAILED, see docs/_build/warnings.txt" >&2; exit 1
fi
