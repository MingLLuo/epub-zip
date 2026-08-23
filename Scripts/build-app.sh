#!/bin/zsh
set -euo pipefail

project_dir=${0:A:h:h}
version=$(tr -d '[:space:]' < "$project_dir/VERSION")
configuration=${CONFIGURATION:-release}
architecture_input=${ARCHS:-arm64}
architectures=(${=architecture_input})
(( ${#architectures} > 0 )) || {
  print -u2 -- "ARCHS must contain at least one architecture."
  exit 64
}

arch_args=()
seen_architectures=()
for architecture in $architectures; do
  case "$architecture" in
    arm64|x86_64) ;;
    *)
      print -u2 -- "Unsupported architecture: $architecture"
      exit 64
      ;;
  esac
  (( ${seen_architectures[(Ie)$architecture]} == 0 )) || {
    print -u2 -- "Duplicate architecture: $architecture"
    exit 64
  }
  seen_architectures+=("$architecture")
  arch_args+=(--arch "$architecture")
done

checkout_id=$(print -rn -- "$project_dir" | shasum -a 256 | cut -c 1-12)
scratch_dir=${SCRATCH_PATH:-/private/tmp/epubzip-build-$UID-$checkout_id}
scratch_dir=$("$project_dir/Scripts/validate-scratch-path.sh" "$scratch_dir")
output_dir="$project_dir/dist"
stage_root="$scratch_dir/app-stage"
app_dir="$stage_root/EPUB Zip.app"
signing_identity=${CODESIGN_IDENTITY:--}

if git -C "$project_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  source_commit=$(git -C "$project_dir" rev-parse --verify HEAD)
  if [[ -n "$(git -C "$project_dir" status --porcelain --untracked-files=normal)" ]]; then
    source_state=dirty
  else
    source_state=clean
  fi
elif [[ -s "$project_dir/SOURCE-COMMIT" ]]; then
  source_commit=$(tr -d '[:space:]' < "$project_dir/SOURCE-COMMIT")
  source_state=source-archive
else
  source_commit=unknown
  source_state=untracked
fi

if [[ "$signing_identity" == "-" ]]; then
  artifact_label=development
  build_notice="Development artifact: ad-hoc signed and not notarized. Do not publish it as an official release."
else
  [[ "$source_state" == clean ]] || {
    print -u2 -- "Developer ID candidates must be built from a clean Git worktree."
    exit 65
  }
  artifact_label=signed-not-notarized
  build_notice="Distribution candidate: Developer ID signed with hardened runtime, but not yet notarized."
fi

architecture_label=${(j:-:)architectures}
archive_name="EPUB Zip-$version-$architecture_label-$artifact_label.zip"
dmg_name="EPUB Zip-$version-$architecture_label-$artifact_label.dmg"

rm -rf -- "$stage_root"

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
  -debug-info-format none \
  --product EPUBZipApp \
  $arch_args

bin_dir=$(swift build \
  $swift_paths \
  -c "$configuration" \
  --show-bin-path \
  $arch_args)
binary="$bin_dir/EPUBZipApp"
actual_architecture_input=$(lipo -archs "$binary")
actual_architectures=(${=actual_architecture_input})
(( ${#actual_architectures} == ${#architectures} )) || {
  print -u2 -- "Unexpected app architectures: ${(j: :)actual_architectures}"
  exit 1
}
for architecture in $architectures; do
  (( ${actual_architectures[(Ie)$architecture]} > 0 )) || {
    print -u2 -- "App is missing requested architecture: $architecture"
    exit 1
  }
done

mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$project_dir/Resources/Info.plist" "$app_dir/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $version" "$app_dir/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $version" "$app_dir/Contents/Info.plist"
cp "$binary" "$app_dir/Contents/MacOS/EPUB Zip"
cp "$project_dir/Resources/PrivacyInfo.xcprivacy" "$app_dir/Contents/Resources/"
cp "$project_dir/Resources/AppIcon.icns" "$app_dir/Contents/Resources/"
cp "$project_dir/LICENSE" "$app_dir/Contents/Resources/LICENSE"
cp "$project_dir/THIRD_PARTY_NOTICES.md" "$app_dir/Contents/Resources/THIRD_PARTY_NOTICES.md"
print -r -- "$source_commit" > "$app_dir/Contents/Resources/SOURCE-COMMIT"
print -r -- "$source_state" > "$app_dir/Contents/Resources/SOURCE-STATE"
print -r -- "$build_notice" > "$app_dir/Contents/Resources/BUILD-NOTICE.txt"
if [[ -d "$bin_dir/ZIPFoundation_ZIPFoundation.bundle" ]]; then
  cp -R "$bin_dir/ZIPFoundation_ZIPFoundation.bundle" "$app_dir/Contents/Resources/"
fi
chmod 755 "$app_dir/Contents/MacOS/EPUB Zip"

if [[ "$signing_identity" == "-" ]]; then
  codesign --force --sign - "$app_dir"
  print -u2 -- "Built an ad-hoc-signed development app; it is not notarized."
else
  codesign --force --options runtime --timestamp --sign "$signing_identity" "$app_dir"
  signing_details=$(codesign --display --verbose=4 "$app_dir" 2>&1)
  [[ "$signing_details" == *"Authority=Developer ID Application:"* && "$signing_details" == *runtime* ]] || {
    print -u2 -- "The app needs a Developer ID Application signature with hardened runtime."
    exit 1
  }
fi
codesign --verify --deep --strict --verbose=2 "$app_dir"

mkdir -p "$output_dir"
rm -f -- "$output_dir/$archive_name"
ditto -c -k --norsrc --noextattr --noqtn --noacl --keepParent "$app_dir" "$output_dir/$archive_name"

dmg_source="$stage_root/dmg"
mkdir -p "$dmg_source"
cp -R "$app_dir" "$dmg_source/"
ln -s /Applications "$dmg_source/Applications"
rm -f -- "$output_dir/$dmg_name"
hdiutil create -quiet -volname "EPUB Zip" -srcfolder "$dmg_source" -ov -format UDZO "$output_dir/$dmg_name"

print -r -- "$output_dir/$archive_name"
print -r -- "$output_dir/$dmg_name"
