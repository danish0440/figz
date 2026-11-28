#!/usr/bin/env bash
# Validate the staged Arch launcher without building or opening FigZ.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
stage="$work/source"
dst="$work/dist"
base=figz-0.0.1-nightly.1-linux-x86_64
mkdir -p "$stage/bin" "$dst" "$work/extract"

# A local argv + XDG recorder stands in for the compiled binaries. It never opens a UI.
cat >"$stage/bin/figz" <<'RECORDER'
#!/bin/sh
printf 'CONFIG=%s\nDATA=%s\n' "${XDG_CONFIG_HOME:-}" "${XDG_DATA_HOME:-}"
printf '<%s>\n' "$@"
RECORDER
chmod 755 "$stage/bin/figz"
cp "$stage/bin/figz" "$stage/bin/figz-cli"

bash "$HERE/nightly-arch-tar.sh" "$stage" "$work/stage" "$dst" "$base"
tar -xzf "$dst/$base.tar.gz" -C "$work/extract"
bin="$work/extract/$base/bin"
# Simulate the existing Arch bin-tree copy and public launcher rename.
mkdir -p "$work/installed"
cp -R "$bin" "$work/installed/bin"
bin="$work/installed/bin"
mv "$bin/figz" "$bin/figz-nightly"
mv "$bin/figz-cli" "$bin/figz-nightly-cli"

[[ ! -e "$stage/bin/.figz-nightly" ]]
cmp "$stage/bin/figz" "$bin/.figz-nightly/figz"
cmp "$stage/bin/figz-cli" "$bin/figz-nightly-cli"
export HOME="$work/home with space"
unset XDG_CONFIG_HOME XDG_DATA_HOME
# The launcher starts the GUI on the Launcher's nightly-v1 profile under the per-channel data dir,
# so the profile it passes must be the one the flavor's fence accepts.
# Every argument the launcher adds, printed the way the recorder shows them.
profile_at() {
  printf -- '<--launch-profile>\n<nightly-v1>\n<--profile-root>\n<%s/profile>\n<-->' "$1"
}
expect() {
  expected="$1"
  shift
  actual=$(PATH="$bin:$PATH" figz-nightly "$@")
  if [[ "$actual" != "$expected" ]]; then
    printf 'expected:\n%s\nactual:\n%s\n' "$expected" "$actual" >&2
    exit 1
  fi
}
expect "$(printf 'CONFIG=%s\nDATA=%s\n%s' "$HOME/.config/figz-nightly" "$HOME/.local/share/figz-nightly" "$(profile_at "$HOME/.local/share/figz-nightly")")"
export XDG_CONFIG_HOME="$work/xdg config with space"
export XDG_DATA_HOME="$work/xdg data with space"
expect "$(printf 'CONFIG=%s\nDATA=%s\n%s\n<%s>\n<%s>\n' "$XDG_CONFIG_HOME/figz-nightly" "$XDG_DATA_HOME/figz-nightly" \
  "$(profile_at "$XDG_DATA_HOME/figz-nightly")" 'design with spaces.figz' '--other-name.figz')" \
  'design with spaces.figz' '--other-name.figz'
# A version query is answered by the GUI itself: no profile directory is created for it.
expect "$(printf 'CONFIG=%s\nDATA=%s\n<--version>\n' "$XDG_CONFIG_HOME" "$XDG_DATA_HOME")" --version
expect "$(printf 'CONFIG=%s\nDATA=%s\n<-V>\n' "$XDG_CONFIG_HOME" "$XDG_DATA_HOME")" -V
# The Launcher's own protocol passes through untouched: never a second pair, and the caller's
# folders are left as they were.
expect "$(printf 'CONFIG=%s\nDATA=%s\n<--launch-profile>\n<nightly-v1>\n<--profile-root>\n<%s>\n<-->\n<%s>\n' \
  "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$work/launcher profile" 'a.figz')" \
  --launch-profile nightly-v1 --profile-root "$work/launcher profile" -- 'a.figz'
[[ ! -e "$XDG_DATA_HOME/figz-nightly" ]] || { echo "FAIL: a version query created the profile" >&2; exit 1; }

echo "PASS: Arch Nightly handoff starts the nightly-v1 profile and preserves launch arguments"
