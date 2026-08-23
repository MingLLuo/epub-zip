#!/bin/zsh
set -euo pipefail

if (( $# < 1 || $# > 2 )); then
  print -u2 -- "Usage: NOTARYTOOL_PROFILE=<profile> ${0:t} <signed-not-notarized.dmg> [notarized.dmg]"
  exit 64
fi

input_dmg=${1:A}
[[ -s "$input_dmg" && "${input_dmg:e}" == dmg ]] || {
  print -u2 -- "Input must be an existing DMG: $1"
  exit 66
}
[[ "${input_dmg:t}" == *-signed-not-notarized.dmg ]] || {
  print -u2 -- "Input name must end with '-signed-not-notarized.dmg'."
  exit 64
}
profile=${NOTARYTOOL_PROFILE:-}
[[ -n "$profile" ]] || {
  print -u2 -- "Set NOTARYTOOL_PROFILE to a notarytool keychain profile."
  exit 64
}

default_output="${input_dmg%-signed-not-notarized.dmg}-notarized.dmg"
output_dmg=${2:-$default_output}
output_dmg=${output_dmg:A}
[[ "${output_dmg:t}" == "${default_output:t}" ]] || {
  print -u2 -- "Output name must be '${default_output:t}'."
  exit 64
}
[[ "$output_dmg" != "$input_dmg" ]] || {
  print -u2 -- "Output must differ from the signed, unnotarized input."
  exit 64
}
[[ ! -e "$output_dmg" ]] || {
  print -u2 -- "Output already exists; refusing to overwrite it: $output_dmg"
  exit 73
}

mount_point=$(mktemp -d "${TMPDIR:-/tmp}/epubzip-notary-check.XXXXXX")
notary_result=$(mktemp "${TMPDIR:-/tmp}/epubzip-notary-result.XXXXXX")
mounted=false
output_created=false
notarization_complete=false
cleanup() {
  if [[ "$mounted" == true ]]; then
    hdiutil detach -quiet "$mount_point" || true
  fi
  rmdir "$mount_point" 2>/dev/null || true
  rm -f -- "$notary_result"
  if [[ "$output_created" == true && "$notarization_complete" != true ]]; then
    rm -f -- "$output_dmg"
  fi
}
trap cleanup EXIT

hdiutil attach -quiet -readonly -nobrowse -mountpoint "$mount_point" "$input_dmg"
mounted=true
app="$mount_point/EPUB Zip.app"
[[ -d "$app" ]] || {
  print -u2 -- "The DMG does not contain EPUB Zip.app."
  exit 65
}
codesign --verify --deep --strict --verbose=2 "$app"
signing_details=$(codesign --display --verbose=4 "$app" 2>&1)
[[ "$signing_details" == *"Authority=Developer ID Application:"* && "$signing_details" == *runtime* ]] || {
  print -u2 -- "The app must have a Developer ID Application signature with hardened runtime."
  exit 65
}
hdiutil detach -quiet "$mount_point"
mounted=false

cp "$input_dmg" "$output_dmg"
output_created=true
xcrun notarytool submit "$output_dmg" \
  --keychain-profile "$profile" \
  --wait \
  --output-format json > "$notary_result"
notary_status=$(plutil -extract status raw "$notary_result")
notary_id=$(plutil -extract id raw "$notary_result")
[[ "$notary_status" == Accepted ]] || {
  print -u2 -- "Notarization $notary_id finished with status: $notary_status"
  exit 65
}
xcrun stapler staple "$output_dmg"
xcrun stapler validate "$output_dmg"
spctl --assess --type open --context context:primary-signature --verbose=2 "$output_dmg"
notarization_complete=true

print -- "Notarization accepted: $notary_id"
print -r -- "$output_dmg"
shasum -a 256 -- "$output_dmg"
