# nix-build '<nixpkgs/botnix>' -A config.system.build.cloudstackImage --arg configuration "{ imports = [ ./botnix/maintainers/scripts/cloudstack/cloudstack-image.nix ]; }"

{ config, lib, pkgs, ... }:

{
  imports =
    [ ../../../modules/virtualisation/cloudstack-config.nix ];

  system.build.cloudstackImage = import ../../../lib/make-disk-image.nix {
    inherit lib config pkgs;
    format = "qcow2";
    configFile = pkgs.writeText "configuration.nix"
      ''
        {
          imports = [ <nixpkgs/botnix/modules/virtualisation/cloudstack-config.nix> ];
        }
      '';
  };

}
