#!/usr/bin/env bash
# Clone ulank6 at the pinned ref and apply the charge-limit patches.
set -euo pipefail

REPO_DIR=$(cd "$(dirname "$0")/.." && pwd)
ULANK6_URL=${ULANK6_URL:-https://github.com/gedulab/ulank6.git}
ULANK6_REF=${ULANK6_REF:-4ff601f9}
SRC_DIR=${SRC_DIR:-$REPO_DIR/ulank6}

if [ ! -d "$SRC_DIR/.git" ]; then
	echo "==> clone $ULANK6_URL -> $SRC_DIR"
	git clone "$ULANK6_URL" "$SRC_DIR"
fi

cd "$SRC_DIR"
git fetch --all --tags --quiet || true
git checkout "$ULANK6_REF"

echo "==> apply patches from $REPO_DIR/patches"
git am -3 "$REPO_DIR"/patches/*.patch

echo "==> done:"
git log --oneline -3
