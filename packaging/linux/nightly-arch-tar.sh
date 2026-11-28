#!/usr/bin/env bash
# Stage the FigZ Nightly-only handoff for the Arch packager.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
source_tree="$1"
work="$2"
destination="$3"
basename="$4"
stage="$work/$basename"

mkdir -p "$work"
cp -R "$source_tree" "$stage"
mkdir "$stage/bin/.figz-nightly"
mv "$stage/bin/figz" "$stage/bin/.figz-nightly/figz"
awk -v real='"$(dirname "$0")/.figz-nightly/figz"' '{ gsub(/@REAL_BIN@/, real); print }' \
  "$here/nightly-package-launch.sh" >"$stage/bin/figz"
chmod 755 "$stage/bin/figz"
tar -C "$work" -czf "$destination/$basename.tar.gz" "$basename"
echo "wrote $destination/$basename.tar.gz"
