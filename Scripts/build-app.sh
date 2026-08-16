#!/bin/zsh
set -euo pipefail

project_dir=${0:A:h:h}
configuration=${CONFIGURATION:-release}
architectures=(${ARCHS:-arm64})
arch_args=()
for architecture in $architectures; do
  arch_args+=(--arch "$architecture")
done
scratch_dir=${SCRATCH_PATH:-/private/tmp/epubzip-build-$UID}
output_dir="$project_dir/dist"
stage_root="$scratch_dir/app-stage"
app_dir="$stage_root/EPUB Zip.app"
archive_name="EPUB Zip-0.1.0-${(j:-:)architectures}.zip"

rm -rf "$stage_root"

export CLANG_MODULE_CACHE_PATH="$scratch_dir/clang-module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$scratch_dir/swift-module-cache"
swift_paths=(
  --disable-sandbox
  --package-path "$project_dir"
  --scratch-path "$scratch_dir"
  --cache-path "$scratch_dir/package-cache"
  --config-path "$scratch_dir/config"
  --security-path "$scratch_dir/security"
)

swift build \
  $swift_paths \
  -c "$configuration" \
  -Xswiftc -gnone \
  --product EPUBZipApp \
  $arch_args

bin_dir=$(swift build \
  $swift_paths \
  -c "$configuration" \
  --show-bin-path \
  $arch_args)

mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$project_dir/Resources/Info.plist" "$app_dir/Contents/Info.plist"
cp "$bin_dir/EPUBZipApp" "$app_dir/Contents/MacOS/EPUB Zip"
if [[ -d "$bin_dir/ZIPFoundation_ZIPFoundation.bundle" ]]; then
  cp -R "$bin_dir/ZIPFoundation_ZIPFoundation.bundle" "$app_dir/Contents/Resources/"
fi
chmod 755 "$app_dir/Contents/MacOS/EPUB Zip"
codesign --force --deep --sign - "$app_dir"
codesign --verify --deep --strict "$app_dir"

mkdir -p "$output_dir"
rm -f "$output_dir/$archive_name"
ditto -c -k --norsrc --noextattr --noqtn --noacl --keepParent "$app_dir" "$output_dir/$archive_name"
echo "$output_dir/$archive_name"
