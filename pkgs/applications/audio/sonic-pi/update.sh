#!/usr/bin/env nix-shell
#!nix-shell -i bash -p nix jq common-updater-scripts

set -euo pipefail

botpkgs="$(git rev-parse --show-toplevel || (printf 'Could not find root of botpkgs repo\nAre we running from within the botpkgs git repo?\n' >&2; exit 1))"

stripwhitespace() {
    sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

nixeval() {
    nix --extra-experimental-features nix-command eval --json --impure -f "$botpkgs" "$1" | jq -r .
}

vendorhash() {
    (nix --extra-experimental-features nix-command build --impure --argstr botpkgs "$botpkgs" --argstr attr "$1" --expr '{ botpkgs, attr }: let pkgs = import botpkgs {}; in with pkgs.lib; (getAttrFromPath (splitString "." attr) pkgs).overrideAttrs (attrs: { outputHash = fakeHash; })' --no-link 2>&1 >/dev/null | tail -n3 | grep -F got: | cut -d: -f2- | stripwhitespace) 2>/dev/null || true
}

findpath() {
    path="$(nix --extra-experimental-features nix-command eval --json --impure -f "$botpkgs" "$1.meta.position" | jq -r . | cut -d: -f1)"
    outpath="$(nix --extra-experimental-features nix-command eval --json --impure --expr "builtins.fetchGit \"$botpkgs\"")"

    if [ -n "$outpath" ]; then
        path="${path/$(echo "$outpath" | jq -r .)/$botpkgs}"
    fi

    echo "$path"
}

attr="${UPDATE_NIX_ATTR_PATH:-sonic-pi}"
version="$(cd "$botpkgs" && list-git-tags --pname="$(nixeval "$attr".pname)" --attr-path="$attr" | grep '^v' | sed -e 's|^v||' | sort -V | tail -n1)"

pkgpath="$(findpath "$attr")"

updated="$(cd "$botpkgs" && update-source-version "$attr" "$version" --file="$pkgpath" --print-changes | jq -r length)"

if [ "$updated" -eq 0 ]; then
    echo 'update.sh: Package version not updated, nothing to do.'
    exit 0
fi

curhash="$(nixeval "$attr.mixFodDeps.outputHash")"
newhash="$(vendorhash "$attr.mixFodDeps")"

if [ -n "$newhash" ] && [ "$curhash" != "$newhash" ]; then
    sed -i -e "s|\"$curhash\"|\"$newhash\"|" "$pkgpath"
else
    echo 'update.sh: New vendorHash same as old vendorHash, nothing to do.'
fi
