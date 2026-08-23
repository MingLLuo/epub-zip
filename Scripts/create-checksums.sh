#!/bin/zsh
set -euo pipefail

project_dir=${0:A:h:h}
version=$(tr -d '[:space:]' < "$project_dir/VERSION")
artifact_dir=${1:-$project_dir/dist}
artifact_dir=${artifact_dir:A}
[[ -d "$artifact_dir" ]] || {
  print -u2 -- "Artifact directory does not exist: $artifact_dir"
  exit 66
}

artifacts=(
  "$artifact_dir"/*"$version"*.zip(N)
  "$artifact_dir"/*"$version"*.dmg(N)
  "$artifact_dir"/MinimalBook.epub(N)
)
(( ${#artifacts} > 0 )) || {
  print -u2 -- "No version $version artifacts found in $artifact_dir"
  exit 66
}

checksum_file="$artifact_dir/SHA256SUMS"
temporary_file=$(mktemp "$artifact_dir/.SHA256SUMS.XXXXXX")
trap 'rm -f -- "$temporary_file"' EXIT

(
  cd "$artifact_dir"
  for artifact in ${(on)artifacts}; do
    shasum -a 256 -- "${artifact:t}"
  done
) > "$temporary_file"
mv -f -- "$temporary_file" "$checksum_file"
trap - EXIT
print -r -- "$checksum_file"
