{ config, lib, pkgs, modules, ... }:

with lib;

let

  # Location of the repository on the harddrive
  nixosPath = toString ../..;

  # Check if the path is from the Botnix repository
  isNixOSFile = path:
    let s = toString path; in
      removePrefix nixosPath s != s;

  # Copy modules given as extra configuration files.  Unfortunately, we
  # cannot serialized attribute set given in the list of modules (that's why
  # you should use files).
  moduleFiles =
    # FIXME: use typeOf (Nix 1.6.1).
    filter (x: !isAttrs x && !lib.isFunction x) modules;

  # Partition module files because between Botnix and non-Botnix files.  Botnix
  # files may change if the repository is updated.
  partitionedModuleFiles =
    let p = partition isNixOSFile moduleFiles; in
    { botnix = p.right; others = p.wrong; };

  # Path transformed to be valid on the installation device.  Thus the
  # device configuration could be rebuild.
  relocatedModuleFiles =
    let
      relocateNixOS = path:
        "<botpkgs/botnix" + removePrefix nixosPath (toString path) + ">";
    in
      { botnix = map relocateNixOS partitionedModuleFiles.botnix;
        others = []; # TODO: copy the modules to the install-device repository.
      };

  # A dummy /etc/botnix/configuration.nix in the booted CD that
  # rebuilds the CD's configuration (and allows the configuration to
  # be modified, of course, providing a true live CD).  Problem is
  # that we don't really know how the CD was built - the Nix
  # expression language doesn't allow us to query the expression being
  # evaluated.  So we'll just hope for the best.
  configClone = pkgs.writeText "configuration.nix"
    ''
      { config, pkgs, ... }:

      {
        imports = [ ${toString config.installer.cloneConfigIncludes} ];

        ${config.installer.cloneConfigExtra}
      }
    '';

in

{

  options = {

    installer.cloneConfig = mkOption {
      default = true;
      description = lib.mdDoc ''
        Try to clone the installation-device configuration by re-using it's
        profile from the list of imported modules.
      '';
    };

    installer.cloneConfigIncludes = mkOption {
      default = [];
      example = [ "./botnix/modules/hardware/network/rt73.nix" ];
      description = lib.mdDoc ''
        List of modules used to re-build this installation device profile.
      '';
    };

    installer.cloneConfigExtra = mkOption {
      default = "";
      description = lib.mdDoc ''
        Extra text to include in the cloned configuration.nix included in this
        installer.
      '';
    };
  };

  config = {

    installer.cloneConfigIncludes =
      relocatedModuleFiles.botnix ++ relocatedModuleFiles.others;

    boot.postBootCommands =
      ''
        # Provide a mount point for botnix-install.
        mkdir -p /mnt

        ${optionalString config.installer.cloneConfig ''
          # Provide a configuration for the CD/DVD itself, to allow users
          # to run botnix-rebuild to change the configuration of the
          # running system on the CD/DVD.
          if ! [ -e /etc/botnix/configuration.nix ]; then
            cp ${configClone} /etc/botnix/configuration.nix
          fi
       ''}
      '';

  };

}
