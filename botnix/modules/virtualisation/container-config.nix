{ config, pkgs, lib, ... }:

with lib;

{

  config = mkIf config.boot.isContainer {

    # Disable some features that are not useful in a container.

    # containers don't have a kernel
    boot.kernel.enable = false;
    boot.modprobeConfig.enable = false;

    console.enable = mkDefault false;

    nix.optimise.automatic = mkDefault false; # the store is host managed
    powerManagement.enable = mkDefault false;
    documentation.botnix.enable = mkDefault false;

    networking.useHostResolvConf = mkDefault true;

    # Containers should be light-weight, so start sshd on demand.
    services.openssh.startWhenNeeded = mkDefault true;

    # containers do not need to setup devices
    services.udev.enable = false;

    # containers normally do not need to manage logical volumes
    services.lvm.enable = lib.mkDefault false;

    # Shut up warnings about not having a boot loader.
    system.build.installBootLoader = lib.mkDefault "${pkgs.coreutils}/bin/true";

    # Not supported in systemd-nspawn containers.
    security.audit.enable = false;

    # Use the host's nix-daemon.
    environment.variables.NIX_REMOTE = "daemon";

  };

}
