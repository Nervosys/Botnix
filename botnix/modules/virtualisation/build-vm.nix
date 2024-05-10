{ config, extendModules, lib, ... }:
let

  inherit (lib)
    mkOption
    ;

  vmVariant = extendModules {
    modules = [ ./qemu-vm.nix ];
  };

  vmVariantWithBootLoader = vmVariant.extendModules {
    modules = [
      ({ config, ... }: {
        _file = "botnix/default.nix##vmWithBootLoader";
        virtualisation.useBootLoader = true;
        virtualisation.useEFIBoot =
          config.boot.loader.systemd-boot.enable ||
          config.boot.loader.efi.canTouchEfiVariables;
      })
    ];
  };
in
{
  options = {

    virtualisation.vmVariant = mkOption {
      description = lib.mdDoc ''
        Machine configuration to be added for the vm script produced by `botnix-rebuild build-vm`.
      '';
      inherit (vmVariant) type;
      default = {};
      visible = "shallow";
    };

    virtualisation.vmVariantWithBootLoader = mkOption {
      description = lib.mdDoc ''
        Machine configuration to be added for the vm script produced by `botnix-rebuild build-vm-with-bootloader`.
      '';
      inherit (vmVariantWithBootLoader) type;
      default = {};
      visible = "shallow";
    };

  };

  config = {

    system.build = {
      vm = lib.mkDefault config.virtualisation.vmVariant.system.build.vm;
      vmWithBootLoader = lib.mkDefault config.virtualisation.vmVariantWithBootLoader.system.build.vm;
    };

  };

  # uses extendModules
  meta.buildDocsInSandbox = false;
}
