#!/bin/sh
# The FigZ Nightly launcher for the distro formats this app builds itself: the deb/rpm's
# `usr/bin/figz-nightly`, the AppImage's, and the Arch handoff's `bin/figz`. @REAL_BIN@ is
# substituted where each format installs the file, so those packages keep their own profile folder
# (`XDG_DATA_HOME/figz-nightly/profile`) and the stable-XDG fence they export. The plain nightly
# tar the Launcher installs uses the canonical shared template in nightly-launch.sh instead.
# FigZ Nightly launch wrapper, shared by every nightly Linux format (the flat .tar.gz, the Arch
# handoff, the deb/rpm and the AppImage entry). It starts the GUI on the Launcher's nightly-v1
# profile under a per-channel directory, so a nightly install never reads or writes the stable
# app's settings, recovery copies, plugins, font store or session state.
#
# The GUI binary this starts is substituted where the script is installed: beside the script as
# figz-bin in a tarball, $APPDIR/usr/bin/figz in an AppImage, /usr/lib/figz-nightly/… in
# a deb/rpm, and bin/.figz-nightly/figz in the Arch handoff.
#
# The Launcher speaks this same protocol (`--launch-profile nightly-v1 --profile-root <dir> --`),
# so its command line passes straight through rather than being wrapped in a second pair. A bare
# `--version` or `-V` goes straight to the binary too: the answer must be the plain version line,
# and a version query never creates the profile. Everything else starts the nightly profile.
set -eu
real_bin=@REAL_BIN@
case "${1:-}" in
  --launch-profile | --profile-root | --version | -V) exec "$real_bin" "$@" ;;
esac
config_base="${XDG_CONFIG_HOME:-${HOME:?HOME is required}/.config}"
data_base="${XDG_DATA_HOME:-${HOME:?HOME is required}/.local/share}"
# The bases in effect before the override below: the GUI's profile fence still refuses the stable
# FigZ folders under them (profile_root.rs reads FIGZ_STABLE_<key>).
export FIGZ_STABLE_XDG_CONFIG_HOME="$config_base"
export FIGZ_STABLE_XDG_DATA_HOME="$data_base"
# Belt and braces for anything that still asks the process environment for a folder.
export XDG_CONFIG_HOME="$config_base/figz-nightly"
export XDG_DATA_HOME="$data_base/figz-nightly"
# One profile per channel, chosen here only: a caller cannot point the Nightly at another folder,
# so the fence the GUI applies can never be handed the stable app's config or data directory.
profile="$XDG_DATA_HOME/profile"
# A `--` the caller wrote already separates the files from the options: drop it, so the app is
# handed exactly one and no file name arrives as `--`.
if [ "${1:-}" = "--" ]; then shift; fi
exec "$real_bin" --launch-profile nightly-v1 --profile-root "$profile" -- "$@"
