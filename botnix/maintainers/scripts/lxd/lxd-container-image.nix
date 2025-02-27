{ lib, pkgs, ... }:

{
  imports = [
    ../../../modules/virtualisation/lxc-container.nix
  ];

  virtualisation.lxc.templates.nix = {
    enable = true;
    target = "/etc/botnix/lxd.nix";
    template = ./nix.tpl;
    when = [ "create" "copy" ];
  };

  # copy the config for botnix-rebuild
  system.activationScripts.config = let
    config = pkgs.substituteAll {
      src = ./lxd-container-image-inner.nix;
      stateVersion = lib.trivial.release;
    };
  in ''
    if [ ! -e /etc/botnix/configuration.nix ]; then
      mkdir -p /etc/botnix
      cp ${config} /etc/botnix/configuration.nix
    fi
  '';

  # Network
  networking.useDHCP = false;
  networking.interfaces.eth0.useDHCP = true;
}
