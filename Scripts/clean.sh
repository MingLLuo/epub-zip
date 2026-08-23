#!/bin/zsh
set -euo pipefail

project_dir=${0:A:h:h}
scratch_dir=$("$project_dir/Scripts/validate-scratch-path.sh" "${1:-}")

if [[ -e "$scratch_dir" ]]; then
  rm -rf -- "$scratch_dir"
  print -- "Removed build cache: $scratch_dir"
fi

if [[ -e "$project_dir/dist" ]]; then
  rm -rf -- "$project_dir/dist"
  print -- "Removed artifacts: $project_dir/dist"
fi
