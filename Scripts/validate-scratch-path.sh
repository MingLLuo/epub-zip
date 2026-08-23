#!/bin/zsh
set -euo pipefail

if (( $# != 1 )) || [[ -z "$1" ]]; then
  print -u2 -- "Usage: ${0:t} <scratch-path>"
  exit 64
fi

scratch_dir=${1:A}
scratch_parent=${scratch_dir:h}
scratch_name=${scratch_dir:t}

# Build cleanup is intentionally limited to a uniquely named direct child of
# macOS's canonical temporary directory. This makes SCRATCH_PATH configurable
# without allowing values such as /, the checkout, or a user's home directory.
if [[ "$scratch_parent" != "/private/tmp" || "$scratch_name" != epubzip-* || ${#scratch_name} -lt 16 ]]; then
  print -u2 -- "Refusing unsafe SCRATCH_PATH: $1"
  print -u2 -- "Use a direct child of /private/tmp whose name starts with 'epubzip-' and is at least 16 characters long."
  exit 64
fi

print -r -- "$scratch_dir"
