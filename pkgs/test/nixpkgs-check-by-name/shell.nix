let
  pkgs = import ../../.. {
    config = {};
    overlays = [];
  };
in pkgs.tests.botpkgs-check-by-name.shell
