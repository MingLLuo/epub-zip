#!/bin/zsh
set -euo pipefail

project_dir=${0:A:h:h}
cd "$project_dir"

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  print -u2 -- "Source archives must be built from a Git checkout."
  exit 69
}

worktree_status=$(git status --porcelain --untracked-files=normal)
[[ -z "$worktree_status" ]] || {
  print -u2 -- "Refusing to archive a dirty worktree; commit or stash source changes first."
  print -u2 -- "$worktree_status"
  exit 65
}

version=$(tr -d '[:space:]' < VERSION)
head_version=$(git show HEAD:VERSION | tr -d '[:space:]')
[[ "$head_version" == "$version" ]] || {
  print -u2 -- "HEAD contains VERSION $head_version, but the worktree contains $version."
  exit 65
}

commit=$(git rev-parse --verify HEAD)
output_dir="$project_dir/dist"
archive="$output_dir/EPUB-Zip-$version-source.zip"
stage_root=$(mktemp -d "/private/tmp/epubzip-source-stage.XXXXXX")
source_dir="$stage_root/EPUB-Zip-$version"
source_tar="$stage_root/source.tar"
trap 'rm -rf -- "$stage_root"' EXIT

mkdir -p "$source_dir" "$output_dir"
git archive --format=tar --output="$source_tar" HEAD
tar -xf "$source_tar" -C "$source_dir"
print -r -- "$commit" > "$source_dir/SOURCE-COMMIT"

rm -f -- "$archive"
ditto -c -k --norsrc --noextattr --noqtn --noacl --keepParent "$source_dir" "$archive"
print -r -- "$archive"
