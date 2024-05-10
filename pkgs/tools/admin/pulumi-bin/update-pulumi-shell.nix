{ botpkgs ? import ../../../.. { } }:
with botpkgs;
mkShell {
  packages = [
    pkgs.gh
  ];
}
