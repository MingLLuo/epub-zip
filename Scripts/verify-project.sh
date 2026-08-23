#!/bin/zsh
set -euo pipefail

project_dir=${0:A:h:h}
cd "$project_dir"

fail() {
  print -u2 -- "Verification failed: $*"
  exit 1
}

for required_file in VERSION Package.swift Package.resolved Sources/EPUBZipCore/Models.swift \
  Resources/Info.plist Resources/PrivacyInfo.xcprivacy Resources/AppIcon.png \
  Resources/AppIcon.icns LICENSE THIRD_PARTY_NOTICES.md; do
  [[ -s "$required_file" ]] || fail "missing or empty $required_file"
done

version=$(tr -d '[:space:]' < VERSION)
print -r -- "$version" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' \
  || fail "VERSION must contain three numeric components: $version"

source_version_count=$(grep -c 'public static let current = "' Sources/EPUBZipCore/Models.swift)
[[ "$source_version_count" == 1 ]] || fail "expected one EPUBZipCoreVersion.current declaration"
source_version=$(sed -nE 's/.*public static let current = "([^"]+)".*/\1/p' Sources/EPUBZipCore/Models.swift)
[[ "$source_version" == "$version" ]] || fail "EPUBZipCoreVersion.current is $source_version, expected $version"

plutil -lint Resources/Info.plist Resources/PrivacyInfo.xcprivacy >/dev/null
plist_version=$(plutil -extract CFBundleShortVersionString raw Resources/Info.plist)
[[ "$plist_version" == "$version" ]] || fail "Info.plist version is $plist_version, expected $version"
[[ "$(plutil -extract CFBundleIconFile raw Resources/Info.plist)" == "AppIcon" ]] \
  || fail "Info.plist does not select AppIcon"
[[ "$(plutil -extract NSPrivacyTracking raw Resources/PrivacyInfo.xcprivacy)" == "false" ]] \
  || fail "privacy manifest must declare tracking as false"
plutil -extract NSPrivacyCollectedDataTypes xml1 -o /dev/null Resources/PrivacyInfo.xcprivacy \
  || fail "privacy manifest lacks NSPrivacyCollectedDataTypes"
plutil -extract NSPrivacyAccessedAPITypes xml1 -o /dev/null Resources/PrivacyInfo.xcprivacy \
  || fail "privacy manifest lacks NSPrivacyAccessedAPITypes"

png_width=$(sips -g pixelWidth Resources/AppIcon.png 2>/dev/null | awk '/pixelWidth:/ {print $2}')
png_height=$(sips -g pixelHeight Resources/AppIcon.png 2>/dev/null | awk '/pixelHeight:/ {print $2}')
[[ "$png_width" == 1024 && "$png_height" == 1024 ]] \
  || fail "AppIcon.png must be 1024 by 1024 pixels"
file Resources/AppIcon.icns | grep -q 'Mac OS X icon' || fail "AppIcon.icns is not a macOS icon"

manifest_dependency=$(sed -nE 's/.*\.upToNextMinor\(from: "([^"]+)"\).*/\1/p' Package.swift)
[[ -n "$manifest_dependency" ]] || fail "could not read ZIPFoundation requirement from Package.swift"
[[ "$(plutil -extract pins.0.identity raw Package.resolved)" == "zipfoundation" ]] \
  || fail "the first resolved dependency is not ZIPFoundation"
resolved_dependency=$(plutil -extract pins.0.state.version raw Package.resolved)
[[ "$resolved_dependency" == "$manifest_dependency" ]] \
  || fail "ZIPFoundation resolves to $resolved_dependency, expected $manifest_dependency"

grep -q '^MIT License$' LICENSE || fail "project LICENSE is not present"
grep -q '^## ZIPFoundation$' THIRD_PARTY_NOTICES.md || fail "ZIPFoundation notice is missing"
grep -q 'Copyright (c) 2017-2025 Thomas Zoechling' THIRD_PARTY_NOTICES.md \
  || fail "ZIPFoundation copyright notice is incomplete"

print -- "Project metadata verified for EPUB Zip $version (ZIPFoundation $resolved_dependency)."
