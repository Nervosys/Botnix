#! /usr/bin/env bash

set -euo pipefail

export NIX_PATH=botpkgs=$(dirname $(readlink -f $0))/../../../..
export BOTNIX_CONFIG=$(dirname $(readlink -f $0))/../../../modules/virtualisation/oci-image.nix

if (( $# < 1 )); then
    (
    echo "Usage: create-image.sh <architecture>"
    echo
    echo "Where <architecture> is one of:"
    echo "  x86_64-linux"
    echo "  aarch64-linux"
    ) >&2
fi

system="$1"; shift

nix-build '<botpkgs/botnix>' \
    -A config.system.build.OCIImage \
    --argstr system "$system" \
    --option system-features kvm \
    -o oci-image
