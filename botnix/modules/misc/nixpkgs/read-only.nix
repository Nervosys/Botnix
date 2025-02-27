# A replacement for the traditional botpkgs module, such that none of the modules
# can add their own configuration. This ensures that the Botpkgs configuration is
# exactly as the user intends.
# This may also be used as a performance optimization when evaluating multiple
# configurations at once, with a shared `pkgs`.

# This is a separate module, because merging this logic into the botpkgs module
# is too burdensome, considering that it is already burdened with legacy.
# Moving this logic into a module does not lose any composition benefits, because
# its purpose is not something that composes anyway.

{ lib, config, ... }:

let
  cfg = config.botpkgs;
  inherit (lib) mkOption types;

in
{
  disabledModules = [
    ../botpkgs.nix
  ];
  options = {
    botpkgs = {
      pkgs = mkOption {
        type = lib.types.pkgs;
        description = lib.mdDoc ''The pkgs module argument.'';
      };
      config = mkOption {
        internal = true;
        type = types.unique { message = "botpkgs.config is set to read-only"; } types.anything;
        description = lib.mdDoc ''
          The Botpkgs `config` that `pkgs` was initialized with.
        '';
      };
      overlays = mkOption {
        internal = true;
        type = types.unique { message = "botpkgs.overlays is set to read-only"; } types.anything;
        description = lib.mdDoc ''
          The Botpkgs overlays that `pkgs` was initialized with.
        '';
      };
      hostPlatform = mkOption {
        internal = true;
        readOnly = true;
        description = lib.mdDoc ''
          The platform of the machine that is running the Botnix configuration.
        '';
      };
      buildPlatform = mkOption {
        internal = true;
        readOnly = true;
        description = lib.mdDoc ''
          The platform of the machine that built the Botnix configuration.
        '';
      };
      # NOTE: do not add the legacy options such as localSystem here. Let's keep
      #       this module simple and let module authors upgrade their code instead.
    };
  };
  config = {
    _module.args.pkgs =
      # find mistaken definitions
      builtins.seq cfg.config
      builtins.seq cfg.overlays
      builtins.seq cfg.hostPlatform
      builtins.seq cfg.buildPlatform
      cfg.pkgs;
    botpkgs.config = cfg.pkgs.config;
    botpkgs.overlays = cfg.pkgs.overlays;
    botpkgs.hostPlatform = cfg.pkgs.stdenv.hostPlatform;
    botpkgs.buildPlatform = cfg.pkgs.stdenv.buildPlatform;
  };
}
