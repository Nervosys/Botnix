#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash curl nix jq common-updater-scripts

set -euo pipefail

botpkgs="$(git rev-parse --show-toplevel || (printf 'Could not find root of botpkgs repo\nAre we running from within the botpkgs git repo?\n' >&2; exit 1))"

stripwhitespace() {
    sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

nixeval() {
    nix --extra-experimental-features nix-command eval --json --impure -f "$botpkgs" "$1" | jq -r .
}

nixbuildscript() {
    nix --extra-experimental-features nix-command build --impure -f "$botpkgs" "$1" --no-link --print-out-paths
}

findpath() {
    path="$(nix --extra-experimental-features nix-command eval --json --impure -f "$botpkgs" "$1.meta.position" | jq -r . | cut -d: -f1)"
    outpath="$(nix --extra-experimental-features nix-command eval --json --impure --expr "builtins.fetchGit \"$botpkgs\"")"

    if [ -n "$outpath" ]; then
        path="${path/$(echo "$outpath" | jq -r .)/$botpkgs}"
    fi

    echo "$path"
}

attr="${UPDATE_NIX_ATTR_PATH:-openutau}"
version="$(curl -sSL "https://api.github.com/repos/stakira/OpenUtau/releases/latest" | jq -r .tag_name | sed -e 's|^build/||')"

pkgpath="$(findpath "$attr")"

updated="$(cd "$botpkgs" && update-source-version "$attr" "$version" --file="$pkgpath" --print-changes | jq -r length)"

if [ "$updated" -eq 0 ]; then
    echo 'update.sh: Package version not updated, nothing to do.'
    exit 0
fi

(cd "$(dirname "$pkgpath")" && "$(nixbuildscript "$attr.fetch-deps")" "$(dirname "$pkgpath")/deps.nix")
