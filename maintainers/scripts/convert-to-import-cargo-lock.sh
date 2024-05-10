#!/usr/bin/env nix-shell
#!nix-shell -I botpkgs=. -i bash -p "import ./maintainers/scripts/convert-to-import-cargo-lock" nix-prefetch-git

convert-to-import-cargo-lock "$@"
