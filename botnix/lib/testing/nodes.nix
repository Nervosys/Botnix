testModuleArgs@{ config, lib, hostPkgs, nodes, ... }:

let
  inherit (lib)
    literalExpression
    literalMD
    mapAttrs
    mdDoc
    mkDefault
    mkIf
    mkOption mkForce
    optional
    optionalAttrs
    types
    ;

  baseOS =
    import ../eval-config.nix {
      inherit lib;
      system = null; # use modularly defined system
      inherit (config.node) specialArgs;
      modules = [ config.defaults ];
      baseModules = (import ../../modules/module-list.nix) ++
        [
          ./botnix-test-base.nix
          { key = "nodes"; _module.args.nodes = config.nodesCompat; }
          ({ config, ... }:
            {
              virtualisation.qemu.package = testModuleArgs.config.qemu.package;
            })
          ({ options, ... }: {
            key = "nodes.nix-pkgs";
            config = optionalAttrs (!config.node.pkgsReadOnly) (
              mkIf (!options.botpkgs.pkgs.isDefined) {
                # TODO: switch to botpkgs.hostPlatform and make sure containers-imperative test still evaluates.
                botpkgs.system = hostPkgs.stdenv.hostPlatform.system;
              }
            );
          })
          testModuleArgs.config.extraBaseModules
        ];
    };


in

{

  options = {
    node.type = mkOption {
      type = types.raw;
      default = baseOS.type;
      internal = true;
    };

    nodes = mkOption {
      type = types.lazyAttrsOf config.node.type;
      visible = "shallow";
      description = mdDoc ''
        An attribute set of Botnix configuration modules.

        The configurations are augmented by the [`defaults`](#test-opt-defaults) option.

        They are assigned network addresses according to the `botnix/lib/testing/network.nix` module.

        A few special options are available, that aren't in a plain Botnix configuration. See [Configuring the nodes](#sec-botnix-test-nodes)
      '';
    };

    defaults = mkOption {
      description = mdDoc ''
        Botnix configuration that is applied to all [{option}`nodes`](#test-opt-nodes).
      '';
      type = types.deferredModule;
      default = { };
    };

    extraBaseModules = mkOption {
      description = mdDoc ''
        Botnix configuration that, like [{option}`defaults`](#test-opt-defaults), is applied to all [{option}`nodes`](#test-opt-nodes) and can not be undone with [`specialisation.<name>.inheritParentConfig`](https://search.nixos.org/options?show=specialisation.%3Cname%3E.inheritParentConfig&from=0&size=50&sort=relevance&type=packages&query=specialisation).
      '';
      type = types.deferredModule;
      default = { };
    };

    node.pkgs = mkOption {
      description = mdDoc ''
        The Botpkgs to use for the nodes.

        Setting this will make the `botpkgs.*` options read-only, to avoid mistakenly testing with a Botpkgs configuration that diverges from regular use.
      '';
      type = types.nullOr types.pkgs;
      default = null;
      defaultText = literalMD ''
        `null`, so construct `pkgs` according to the `botpkgs.*` options as usual.
      '';
    };

    node.pkgsReadOnly = mkOption {
      description = mdDoc ''
        Whether to make the `botpkgs.*` options read-only. This is only relevant when [`node.pkgs`](#test-opt-node.pkgs) is set.

        Set this to `false` when any of the [`nodes`](#test-opt-nodes) needs to configure any of the `botpkgs.*` options. This will slow down evaluation of your test a bit.
      '';
      type = types.bool;
      default = config.node.pkgs != null;
      defaultText = literalExpression ''node.pkgs != null'';
    };

    node.specialArgs = mkOption {
      type = types.lazyAttrsOf types.raw;
      default = { };
      description = mdDoc ''
        An attribute set of arbitrary values that will be made available as module arguments during the resolution of module `imports`.

        Note that it is not possible to override these from within the Botnix configurations. If you argument is not relevant to `imports`, consider setting {option}`defaults._module.args.<name>` instead.
      '';
    };

    nodesCompat = mkOption {
      internal = true;
      description = mdDoc ''
        Basically `_module.args.nodes`, but with backcompat and warnings added.

        This will go away.
      '';
    };
  };

  config = {
    _module.args.nodes = config.nodesCompat;
    nodesCompat =
      mapAttrs
        (name: config: config // {
          config = lib.warnIf (lib.isInOldestRelease 2211)
            "Module argument `nodes.${name}.config` is deprecated. Use `nodes.${name}` instead."
            config;
        })
        config.nodes;

    passthru.nodes = config.nodesCompat;

    defaults = mkIf config.node.pkgsReadOnly {
      botpkgs.pkgs = config.node.pkgs;
      imports = [ ../../modules/misc/botpkgs/read-only.nix ];
    };

  };
}
