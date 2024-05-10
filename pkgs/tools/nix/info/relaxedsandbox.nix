let
  pkgs = import <botpkgs> {};
in pkgs.runCommand "diagnostics-sandbox"
  {
    __noChroot = true;
  }
  ''
    set -x
    # no cache: ${toString builtins.currentTime}
    test -d "$(dirname "$out")/../var/nix"
    touch $out
  ''
