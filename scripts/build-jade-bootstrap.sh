#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# git+file would hide untracked files from the flake; path: sees the working tree.
nix build --impure --print-out-paths -o result-jade-bootstrap \
  --expr 'import ./hosts/jade/bootstrap.nix { flake = builtins.getFlake "path:'"$PWD"'"; }'
ls -l result-jade-bootstrap/
