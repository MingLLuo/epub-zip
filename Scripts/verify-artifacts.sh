#!/bin/zsh
set -euo pipefail

project_dir=${0:A:h:h}
version=$(tr -d '[:space:]' < "$project_dir/VERSION")
artifact_dir="$project_dir/dist"
signing_identity=${CODESIGN_IDENTITY:--}
if [[ "$signing_identity" == "-" ]]; then
  artifact_label=development
else
  artifact_label=signed-not-notarized
fi

cli_archive="$artifact_dir/epubzip-$version-arm64-cli-$artifact_label.zip"
app_archive="$artifact_dir/EPUB Zip-$version-arm64-$artifact_label.zip"
app_dmg="$artifact_dir/EPUB Zip-$version-arm64-$artifact_label.dmg"
source_archive="$artifact_dir/EPUB-Zip-$version-source.zip"
example="$artifact_dir/MinimalBook.epub"

for artifact in "$cli_archive" "$app_archive" "$app_dmg" "$source_archive" "$example"; do
  [[ -s "$artifact" ]] || {
    print -u2 -- "Missing or empty artifact: $artifact"
    exit 1
  }
done

work_dir=$(mktemp -d "${TMPDIR:-/tmp}/epubzip-artifact-verification.XXXXXX")
trap 'rm -rf -- "$work_dir"' EXIT
ditto -x -k "$cli_archive" "$work_dir/cli"
ditto -x -k "$app_archive" "$work_dir/app"
ditto -x -k "$source_archive" "$work_dir/source"

cli_dir="$work_dir/cli/epubzip-$version-arm64-cli-$artifact_label"
cli="$cli_dir/epubzip"
app="$work_dir/app/EPUB Zip.app"
source_dir="$work_dir/source/EPUB-Zip-$version"

[[ "$(lipo -archs "$cli")" == arm64 ]] || {
  print -u2 -- "Packaged CLI is not arm64-only."
  exit 1
}
[[ "$(lipo -archs "$app/Contents/MacOS/EPUB Zip")" == arm64 ]] || {
  print -u2 -- "Packaged app is not arm64-only."
  exit 1
}
[[ "$($cli --version)" == "epubzip $version" ]] || {
  print -u2 -- "Packaged CLI version is inconsistent."
  exit 1
}

for packaged_file in "$cli_dir/LICENSE" "$cli_dir/THIRD_PARTY_NOTICES.md" "$cli_dir/BUILD-NOTICE.txt" \
  "$app/Contents/Resources/LICENSE" "$app/Contents/Resources/THIRD_PARTY_NOTICES.md" \
  "$app/Contents/Resources/BUILD-NOTICE.txt" "$app/Contents/Resources/AppIcon.icns" \
  "$app/Contents/Resources/PrivacyInfo.xcprivacy"; do
  [[ -s "$packaged_file" ]] || {
    print -u2 -- "Packaged resource is missing: $packaged_file"
    exit 1
  }
done

[[ "$(plutil -extract CFBundleShortVersionString raw "$app/Contents/Info.plist")" == "$version" ]] \
  || { print -u2 -- "Packaged app version is inconsistent."; exit 1; }
[[ "$(plutil -extract CFBundleVersion raw "$app/Contents/Info.plist")" == "$version" ]] \
  || { print -u2 -- "Packaged app build version is inconsistent."; exit 1; }
plutil -lint "$app/Contents/Info.plist" "$app/Contents/Resources/PrivacyInfo.xcprivacy" >/dev/null
codesign --verify --deep --strict --verbose=2 "$app"
codesign --verify --strict --verbose=2 "$cli"
hdiutil verify "$app_dmg" >/dev/null

if [[ "$signing_identity" == "-" ]]; then
  grep -q 'ad-hoc signed and not notarized' "$cli_dir/BUILD-NOTICE.txt"
  grep -q 'ad-hoc signed and not notarized' "$app/Contents/Resources/BUILD-NOTICE.txt"
else
  app_signing_details=$(codesign --display --verbose=4 "$app" 2>&1)
  cli_signing_details=$(codesign --display --verbose=4 "$cli" 2>&1)
  [[ "$app_signing_details" == *"Authority=Developer ID Application:"* \
    && "$cli_signing_details" == *"Authority=Developer ID Application:"* \
    && "$app_signing_details" == *runtime* && "$cli_signing_details" == *runtime* ]] \
    || { print -u2 -- "A distribution artifact lacks Developer ID or hardened runtime."; exit 1; }
fi

first_entry=$(zipinfo -1 "$example" | sed -n '1p')
[[ "$first_entry" == mimetype ]] || {
  print -u2 -- "Example EPUB does not begin with mimetype."
  exit 1
}
"$cli" check "$example" >/dev/null

[[ -d "$source_dir" && ! -e "$source_dir/.git" ]] || {
  print -u2 -- "Source archive layout is invalid."
  exit 1
}
[[ "$(tr -d '[:space:]' < "$source_dir/VERSION")" == "$version" ]] || {
  print -u2 -- "Source archive version is inconsistent."
  exit 1
}
[[ "$(tr -d '[:space:]' < "$source_dir/SOURCE-COMMIT")" == "$(git -C "$project_dir" rev-parse HEAD)" ]] || {
  print -u2 -- "Source archive commit does not match HEAD."
  exit 1
}
"$source_dir/Scripts/verify-project.sh" >/dev/null

print -- "Verified arm64 app, CLI, DMG, source, licenses, privacy manifest, and example EPUB for $version."
