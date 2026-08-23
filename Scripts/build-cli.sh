#!/bin/zsh
set -euo pipefail

project_dir=${0:A:h:h}
version=$(tr -d '[:space:]' < "$project_dir/VERSION")
architecture=arm64
checkout_id=$(print -rn -- "$project_dir" | shasum -a 256 | cut -c 1-12)
scratch_dir=${SCRATCH_PATH:-/private/tmp/epubzip-build-$UID-$checkout_id}
scratch_dir=$("$project_dir/Scripts/validate-scratch-path.sh" "$scratch_dir")
output_dir="$project_dir/dist"
signing_identity=${CODESIGN_IDENTITY:--}

if [[ "$signing_identity" == "-" ]]; then
  artifact_label=development
  build_notice="Development artifact: ad-hoc signed and not notarized. Do not publish it as an official release."
else
  artifact_label=signed-not-notarized
  build_notice="Distribution candidate: Developer ID signed with hardened runtime, but not yet notarized."
fi

stage="$scratch_dir/epubzip-$version-$architecture-cli-$artifact_label"
archive="$output_dir/epubzip-$version-$architecture-cli-$artifact_label.zip"

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
  -c release \
  -debug-info-format none \
  --arch "$architecture" \
  --product epubzip

bin_dir=$(swift build \
  $swift_paths \
  -c release \
  --arch "$architecture" \
  --show-bin-path)
binary="$bin_dir/epubzip"

[[ "$(lipo -archs "$binary")" == "$architecture" ]] || {
  print -u2 -- "Unexpected CLI architectures: $(lipo -archs "$binary")"
  exit 1
}
[[ "$($binary --version)" == "epubzip $version" ]] || {
  print -u2 -- "CLI version does not match VERSION ($version)."
  exit 1
}

rm -rf -- "$stage"
mkdir -p "$stage" "$output_dir"
cp "$binary" "$stage/epubzip"
cp "$project_dir/Resources/CLI-README.txt" "$stage/README.txt"
cp "$project_dir/LICENSE" "$stage/LICENSE"
cp "$project_dir/THIRD_PARTY_NOTICES.md" "$stage/THIRD_PARTY_NOTICES.md"
print -r -- "$build_notice" > "$stage/BUILD-NOTICE.txt"
chmod 755 "$stage/epubzip"

if [[ "$signing_identity" == "-" ]]; then
  codesign --force --sign - "$stage/epubzip"
  print -u2 -- "Built an ad-hoc-signed development CLI; it is not notarized."
else
  codesign --force --options runtime --timestamp --sign "$signing_identity" "$stage/epubzip"
  signing_details=$(codesign --display --verbose=4 "$stage/epubzip" 2>&1)
  [[ "$signing_details" == *"Authority=Developer ID Application:"* && "$signing_details" == *runtime* ]] || {
    print -u2 -- "The CLI needs a Developer ID Application signature with hardened runtime."
    exit 1
  }
fi
codesign --verify --strict --verbose=2 "$stage/epubzip"

rm -f -- "$archive"
ditto -c -k --norsrc --noextattr --noqtn --noacl --keepParent "$stage" "$archive"
print -r -- "$archive"
