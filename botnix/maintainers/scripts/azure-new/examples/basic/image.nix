let
  pkgs = (import ../../../../../../default.nix {});
  machine = import (pkgs.path + "/botnix/lib/eval-config.nix") {
    system = "x86_64-linux";
    modules = [
      ({config, ...}: { imports = [ ./system.nix ]; })
    ];
  };
in
  machine.config.system.build.azureImage
