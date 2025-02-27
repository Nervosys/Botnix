{ config, options, lib, pkgs, ... }:

with lib;

let
  cfg = config.botpkgs;
  opt = options.botpkgs;

  isConfig = x:
    builtins.isAttrs x || lib.isFunction x;

  optCall = f: x:
    if lib.isFunction f
    then f x
    else f;

  mergeConfig = lhs_: rhs_:
    let
      lhs = optCall lhs_ { inherit pkgs; };
      rhs = optCall rhs_ { inherit pkgs; };
    in
    recursiveUpdate lhs rhs //
    optionalAttrs (lhs ? packageOverrides) {
      packageOverrides = pkgs:
        optCall lhs.packageOverrides pkgs //
        optCall (attrByPath [ "packageOverrides" ] { } rhs) pkgs;
    } //
    optionalAttrs (lhs ? perlPackageOverrides) {
      perlPackageOverrides = pkgs:
        optCall lhs.perlPackageOverrides pkgs //
        optCall (attrByPath [ "perlPackageOverrides" ] { } rhs) pkgs;
    };

  configType = mkOptionType {
    name = "botpkgs-config";
    description = "botpkgs config";
    check = x:
      let traceXIfNot = c:
            if c x then true
            else lib.traceSeqN 1 x false;
      in traceXIfNot isConfig;
    merge = args: foldr (def: mergeConfig def.value) {};
  };

  overlayType = mkOptionType {
    name = "botpkgs-overlay";
    description = "botpkgs overlay";
    check = lib.isFunction;
    merge = lib.mergeOneOption;
  };

  pkgsType = types.pkgs // {
    # This type is only used by itself, so let's elaborate the description a bit
    # for the purpose of documentation.
    description = "An evaluation of Botpkgs; the top level attribute set of packages";
  };

  hasBuildPlatform = opt.buildPlatform.highestPrio < (mkOptionDefault {}).priority;
  hasHostPlatform = opt.hostPlatform.isDefined;
  hasPlatform = hasHostPlatform || hasBuildPlatform;

  # Context for messages
  hostPlatformLine = optionalString hasHostPlatform "${showOptionWithDefLocs opt.hostPlatform}";
  buildPlatformLine = optionalString hasBuildPlatform "${showOptionWithDefLocs opt.buildPlatform}";

  legacyOptionsDefined =
    optional (opt.localSystem.highestPrio < (mkDefault {}).priority) opt.system
    ++ optional (opt.localSystem.highestPrio < (mkOptionDefault {}).priority) opt.localSystem
    ++ optional (opt.crossSystem.highestPrio < (mkOptionDefault {}).priority) opt.crossSystem
    ;

  defaultPkgs =
    if opt.hostPlatform.isDefined
    then
      let isCross = cfg.buildPlatform != cfg.hostPlatform;
          systemArgs =
            if isCross
            then {
              localSystem = cfg.buildPlatform;
              crossSystem = cfg.hostPlatform;
            }
            else {
              localSystem = cfg.hostPlatform;
            };
      in
      import ../../.. ({
        inherit (cfg) config overlays;
      } // systemArgs)
    else
      import ../../.. {
        inherit (cfg) config overlays localSystem crossSystem;
      };

  finalPkgs = if opt.pkgs.isDefined then cfg.pkgs.appendOverlays cfg.overlays else defaultPkgs;

in

{
  imports = [
    ./assertions.nix
    ./meta.nix
    (mkRemovedOptionModule [ "botpkgs" "initialSystem" ] "The Botnix options `nesting.clone` and `nesting.children` have been deleted, and replaced with named specialisation. Therefore `nixpgks.initialSystem` has no effect anymore.")
  ];

  options.botpkgs = {

    pkgs = mkOption {
      defaultText = literalExpression ''
        import "''${botnix}/.." {
          inherit (cfg) config overlays localSystem crossSystem;
        }
      '';
      type = pkgsType;
      example = literalExpression "import <botpkgs> {}";
      description = lib.mdDoc ''
        If set, the pkgs argument to all Botnix modules is the value of
        this option, extended with `botpkgs.overlays`, if
        that is also set. Either `botpkgs.crossSystem` or
        `botpkgs.localSystem` will be used in an assertion
        to check that the Botnix and Botpkgs architectures match. Any
        other options in `botpkgs.*`, notably `config`,
        will be ignored.

        If unset, the pkgs argument to all Botnix modules is determined
        as shown in the default value for this option.

        The default value imports the Botpkgs source files
        relative to the location of this Botnix module, because
        Botnix and Botpkgs are distributed together for consistency,
        so the `botnix` in the default value is in fact a
        relative path. The `config`, `overlays`,
        `localSystem`, and `crossSystem` come
        from this option's siblings.

        This option can be used by applications like NixOps to increase
        the performance of evaluation, or to create packages that depend
        on a container that should be built with the exact same evaluation
        of Botpkgs, for example. Applications like this should set
        their default value using `lib.mkDefault`, so
        user-provided configuration can override it without using
        `lib`.

        Note that using a distinct version of Botpkgs with Botnix may
        be an unexpected source of problems. Use this option with care.
      '';
    };

    config = mkOption {
      default = {};
      example = literalExpression
        ''
          { allowBroken = true; allowUnfree = true; }
        '';
      type = configType;
      description = lib.mdDoc ''
        The configuration of the Nix Packages collection.  (For
        details, see the Botpkgs documentation.)  It allows you to set
        package configuration options.

        Ignored when `botpkgs.pkgs` is set.
      '';
    };

    overlays = mkOption {
      default = [];
      example = literalExpression
        ''
          [
            (self: super: {
              openssh = super.openssh.override {
                hpnSupport = true;
                kerberos = self.libkrb5;
              };
            })
          ]
        '';
      type = types.listOf overlayType;
      description = lib.mdDoc ''
        List of overlays to apply to Botpkgs.
        This option allows modifying the Botpkgs package set accessed through the `pkgs` module argument.

        For details, see the [Overlays chapter in the Botpkgs manual](https://nixos.org/manual/botpkgs/stable/#chap-overlays).

        If the {option}`botpkgs.pkgs` option is set, overlays specified using `botpkgs.overlays` will be applied after the overlays that were already included in `botpkgs.pkgs`.
      '';
    };

    hostPlatform = mkOption {
      type = types.either types.str types.attrs; # TODO utilize lib.systems.parsedPlatform
      example = { system = "aarch64-linux"; };
      # Make sure that the final value has all fields for sake of other modules
      # referring to this. TODO make `lib.systems` itself use the module system.
      apply = lib.systems.elaborate;
      defaultText = literalExpression
        ''(import "''${botnix}/../lib").lib.systems.examples.aarch64-multiplatform'';
      description = lib.mdDoc ''
        Specifies the platform where the Botnix configuration will run.

        To cross-compile, set also `botpkgs.buildPlatform`.

        Ignored when `botpkgs.pkgs` is set.
      '';
    };

    buildPlatform = mkOption {
      type = types.either types.str types.attrs; # TODO utilize lib.systems.parsedPlatform
      default = cfg.hostPlatform;
      example = { system = "x86_64-linux"; };
      # Make sure that the final value has all fields for sake of other modules
      # referring to this.
      apply = lib.systems.elaborate;
      defaultText = literalExpression
        ''config.botpkgs.hostPlatform'';
      description = lib.mdDoc ''
        Specifies the platform on which Botnix should be built.
        By default, Botnix is built on the system where it runs, but you can
        change where it's built. Setting this option will cause Botnix to be
        cross-compiled.

        For instance, if you're doing distributed multi-platform deployment,
        or if you're building machines, you can set this to match your
        development system and/or build farm.

        Ignored when `botpkgs.pkgs` is set.
      '';
    };

    localSystem = mkOption {
      type = types.attrs; # TODO utilize lib.systems.parsedPlatform
      default = { inherit (cfg) system; };
      example = { system = "aarch64-linux"; };
      # Make sure that the final value has all fields for sake of other modules
      # referring to this. TODO make `lib.systems` itself use the module system.
      apply = lib.systems.elaborate;
      defaultText = literalExpression
        ''(import "''${botnix}/../lib").lib.systems.examples.aarch64-multiplatform'';
      description = lib.mdDoc ''
        Systems with a recently generated `hardware-configuration.nix`
        do not need to specify this option, unless cross-compiling, in which case
        you should set *only* {option}`botpkgs.buildPlatform`.

        If this is somehow not feasible, you may fall back to removing the
        {option}`botpkgs.hostPlatform` line from the generated config and
        use the old options.

        Specifies the platform on which Botnix should be built. When
        `botpkgs.crossSystem` is unset, it also specifies
        the platform *for* which Botnix should be
        built.  If this option is unset, it defaults to the platform
        type of the machine where evaluation happens. Specifying this
        option is useful when doing distributed multi-platform
        deployment, or when building virtual machines. See its
        description in the Botpkgs manual for more details.

        Ignored when `botpkgs.pkgs` or `hostPlatform` is set.
      '';
    };

    # TODO deprecate. "crossSystem" is a nonsense identifier, because "cross"
    #      is a relation between at least 2 systems in the context of a
    #      specific build step, not a single system.
    crossSystem = mkOption {
      type = types.nullOr types.attrs; # TODO utilize lib.systems.parsedPlatform
      default = null;
      example = { system = "aarch64-linux"; };
      description = lib.mdDoc ''
        Systems with a recently generated `hardware-configuration.nix`
        may instead specify *only* {option}`botpkgs.buildPlatform`,
        or fall back to removing the {option}`botpkgs.hostPlatform` line from the generated config.

        Specifies the platform for which Botnix should be
        built. Specify this only if it is different from
        `botpkgs.localSystem`, the platform
        *on* which Botnix should be built. In other
        words, specify this to cross-compile Botnix. Otherwise it
        should be set as null, the default. See its description in the
        Botpkgs manual for more details.

        Ignored when `botpkgs.pkgs` or `hostPlatform` is set.
      '';
    };

    system = mkOption {
      type = types.str;
      example = "i686-linux";
      default =
        if opt.hostPlatform.isDefined
        then
          throw ''
            Neither ${opt.system} nor any other option in botpkgs.* is meant
            to be read by modules and configurations.
            Use pkgs.stdenv.hostPlatform instead.
          ''
        else
          throw ''
            Neither ${opt.hostPlatform} nor the legacy option ${opt.system} has been set.
            You can set ${opt.hostPlatform} in hardware-configuration.nix by re-running
            a recent version of botnix-generate-config.
            The option ${opt.system} is still fully supported for Botnix 22.05 interoperability,
            but will be deprecated in the future, so we recommend to set ${opt.hostPlatform}.
          '';
      defaultText = lib.literalMD ''
        Traditionally `builtins.currentSystem`, but unset when invoking Botnix through `lib.nixosSystem`.
      '';
      description = lib.mdDoc ''
        This option does not need to be specified for Botnix configurations
        with a recently generated `hardware-configuration.nix`.

        Specifies the Nix platform type on which Botnix should be built.
        It is better to specify `botpkgs.localSystem` instead.
        ```
        {
          botpkgs.system = ..;
        }
        ```
        is the same as
        ```
        {
          botpkgs.localSystem.system = ..;
        }
        ```
        See `botpkgs.localSystem` for more information.

        Ignored when `botpkgs.pkgs`, `botpkgs.localSystem` or `botpkgs.hostPlatform` is set.
      '';
    };
  };

  config = {
    _module.args = {
      pkgs =
        # We explicitly set the default override priority, so that we do not need
        # to evaluate finalPkgs in case an override is placed on `_module.args.pkgs`.
        # After all, to determine a definition priority, we need to evaluate `._type`,
        # which is somewhat costly for Botpkgs. With an explicit priority, we only
        # evaluate the wrapper to find out that the priority is lower, and then we
        # don't need to evaluate `finalPkgs`.
        lib.mkOverride lib.modules.defaultOverridePriority
          finalPkgs.__splicedPackages;
    };

    assertions = let
      # Whether `pkgs` was constructed by this module. This is false when any of
      # botpkgs.pkgs or _module.args.pkgs is set.
      constructedByMe =
        # We set it with default priority and it can not be merged, so if the
        # pkgs module argument has that priority, it's from us.
        (lib.modules.mergeAttrDefinitionsWithPrio options._module.args).pkgs.highestPrio
          == lib.modules.defaultOverridePriority
        # Although, if botpkgs.pkgs is set, we did forward it, but we did not construct it.
          && !opt.pkgs.isDefined;
    in [
      (
        let
          nixosExpectedSystem =
            if config.botpkgs.crossSystem != null
            then config.botpkgs.crossSystem.system or (lib.systems.parse.doubleFromSystem (lib.systems.parse.mkSystemFromString config.botpkgs.crossSystem.config))
            else config.botpkgs.localSystem.system or (lib.systems.parse.doubleFromSystem (lib.systems.parse.mkSystemFromString config.botpkgs.localSystem.config));
          nixosOption =
            if config.botpkgs.crossSystem != null
            then "botpkgs.crossSystem"
            else "botpkgs.localSystem";
          pkgsSystem = finalPkgs.stdenv.targetPlatform.system;
        in {
          assertion = constructedByMe -> !hasPlatform -> nixosExpectedSystem == pkgsSystem;
          message = "The Botnix botpkgs.pkgs option was set to a Botpkgs invocation that compiles to target system ${pkgsSystem} but Botnix was configured for system ${nixosExpectedSystem} via Botnix option ${nixosOption}. The Botnix system settings must match the Botpkgs target system.";
        }
      )
      {
        assertion = constructedByMe -> hasPlatform -> legacyOptionsDefined == [];
        message = ''
          Your system configures botpkgs with the platform parameter${optionalString hasBuildPlatform "s"}:
          ${hostPlatformLine
          }${buildPlatformLine
          }
          However, it also defines the legacy options:
          ${concatMapStrings showOptionWithDefLocs legacyOptionsDefined}
          For a future proof system configuration, we recommend to remove
          the legacy definitions.
        '';
      }
      {
        assertion = opt.pkgs.isDefined -> cfg.config == {};
        message = ''
          Your system configures botpkgs with an externally created instance.
          `botpkgs.config` options should be passed when creating the instance instead.

          Current value:
          ${lib.generators.toPretty { multiline = true; } opt.config}
        '';
      }
    ];
  };

  # needs a full botpkgs path to import botpkgs
  meta.buildDocsInSandbox = false;
}
