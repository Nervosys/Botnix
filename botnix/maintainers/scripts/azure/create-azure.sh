#! /bin/sh -eu

export NIX_PATH=botpkgs=$(dirname $(readlink -f $0))/../../../..
export BOTNIX_CONFIG=$(dirname $(readlink -f $0))/../../../modules/virtualisation/azure-image.nix
export TIMESTAMP=$(date +%Y%m%d%H%M)

nix-build '<botpkgs/botnix>' \
   -A config.system.build.azureImage --argstr system x86_64-linux -o azure -j 10
