{ botpkgs ? import ../.. { }
}:
with botpkgs;
let
  pyEnv = python3.withPackages(ps: with ps; [ packaging requests toolz pyyaml ]);
in
mkShell {
  packages = [
    pyEnv
    nix-prefetch-scripts
  ];
}
