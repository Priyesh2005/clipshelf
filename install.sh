#!/bin/bash
set -euo pipefail
release_version='v0.1.0'
release_name='ClipShelf-0.1.0-macOS.zip'
release_sha='47e6489fb98ff4bc4fe8fc9124e460fa8f9adcf722fcdb654589366c96c9b8ec'
release_url="https://github.com/Priyesh2005/clipshelf/releases/download/${release_version}/${release_name}"
if [ "$(uname -s)" != 'Darwin' ]; then printf 'ClipShelf requires macOS 13 or later.\n' >&2; exit 1; fi
major_version=$(/usr/bin/sw_vers -productVersion | /usr/bin/cut -d. -f1)
if [ "$major_version" -lt 13 ]; then printf 'ClipShelf requires macOS 13 or later.\n' >&2; exit 1; fi
case "$(uname -m)" in arm64|x86_64) ;; *) printf 'Unsupported Mac architecture.\n' >&2; exit 1;; esac
install_parent="$HOME/Applications"
install_destination="$install_parent/ClipShelf.app"
if [ -e "$install_destination" ] || [ -L "$install_destination" ]; then
    printf 'ClipShelf already exists at %s. Nothing was changed.\nQuit it and move the old app aside before installing this beta.\n' "$install_destination" >&2
    exit 1
fi
installer_tmp=$(/usr/bin/mktemp -d /private/tmp/clipshelf-install.XXXXXX)
trap '/bin/rm -rf "$installer_tmp"' EXIT
printf 'Downloading ClipShelf %s…\n' "$release_version"
/usr/bin/curl --fail --location --silent --show-error --proto '=https' --tlsv1.2 "$release_url" -o "$installer_tmp/$release_name"
printf '%s  %s\n' "$release_sha" "$installer_tmp/$release_name" | /usr/bin/shasum -a 256 -c -
/usr/bin/ditto -x -k "$installer_tmp/$release_name" "$installer_tmp/extracted"
/usr/bin/codesign --verify --strict "$installer_tmp/extracted/ClipShelf.app"
/bin/mkdir -p "$install_parent"
# Stage beside the destination so the move stays on the same filesystem.
staging_dir=$(/usr/bin/mktemp -d "$install_parent/.clipshelf-stage.XXXXXX")
trap '/bin/rm -rf "$installer_tmp" "$staging_dir"' EXIT
/usr/bin/ditto "$installer_tmp/extracted/ClipShelf.app" "$staging_dir/ClipShelf.app"
# Keep macOS first-launch checks for this internet download. Do not remove quarantine.
quarantine_stamp=$(printf '%x' "$(date +%s)")
/usr/bin/xattr -w com.apple.quarantine "0083;${quarantine_stamp};ClipShelfInstaller;" "$staging_dir/ClipShelf.app"
if [ -e "$install_destination" ]; then printf 'Destination appeared during installation. Nothing replaced.\n' >&2; exit 1; fi
/bin/mv -n "$staging_dir/ClipShelf.app" "$install_destination"
printf '\nInstalled: %s\nOpen it from Finder, then choose Start Recording.\nDefault shortcut: Control–Option–V.\nThis beta is not Apple-notarized; macOS may require first-launch approval.\n' "$install_destination"
