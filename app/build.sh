#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
build_root=$(mktemp -d /private/tmp/clipshelf-release.XXXXXX)
trap 'rm -rf "$build_root"' EXIT
app_path="$build_root/ClipShelf.app"
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources" release
cp Info.plist "$app_path/Contents/Info.plist"
if [ -f AppIcon.icns ]; then cp AppIcon.icns "$app_path/Contents/Resources/"; fi
for arch in arm64 x86_64; do
    swiftc main.swift -O -o "$build_root/ClipShelf-$arch" -framework AppKit -framework Carbon -framework ServiceManagement -target "$arch-apple-macosx13.0" -module-cache-path "$build_root/module-cache"
done
lipo -create "$build_root/ClipShelf-arm64" "$build_root/ClipShelf-x86_64" -output "$app_path/Contents/MacOS/ClipShelf"
codesign --force --sign - "$app_path"
codesign --verify --strict "$app_path"
"$app_path/Contents/MacOS/ClipShelf" --self-test
COPYFILE_DISABLE=1 /usr/bin/ditto -c -k --norsrc --keepParent "$app_path" release/ClipShelf-0.1.0-macOS.zip
shasum -a 256 release/ClipShelf-0.1.0-macOS.zip > release/SHA256SUMS.txt
printf 'Built release/ClipShelf-0.1.0-macOS.zip (Apple silicon + Intel). Not notarized.\n'
