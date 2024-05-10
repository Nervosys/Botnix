# [botpkgs]$ nix-build -A nixosTests.botpkgs --show-trace

{ evalMinimalConfig, pkgs, lib, stdenv }:
let
  eval = mod: evalMinimalConfig {
    imports = [ ../botpkgs.nix mod ];
  };
  withHost = eval {
    botpkgs.hostPlatform = "aarch64-linux";
  };
  withHostAndBuild = eval {
    botpkgs.hostPlatform = "aarch64-linux";
    botpkgs.buildPlatform = "aarch64-darwin";
  };
  ambiguous = {
    _file = "ambiguous.nix";
    botpkgs.hostPlatform = "aarch64-linux";
    botpkgs.buildPlatform = "aarch64-darwin";
    botpkgs.system = "x86_64-linux";
    botpkgs.localSystem.system = "x86_64-darwin";
    botpkgs.crossSystem.system = "i686-linux";
    imports = [
      { _file = "repeat.nix";
        botpkgs.hostPlatform = "aarch64-linux";
      }
    ];
  };
  getErrors = module:
    let
      uncheckedEval = lib.evalModules { modules = [ ../botpkgs.nix module ]; };
    in map (ass: ass.message) (lib.filter (ass: !ass.assertion) uncheckedEval.config.assertions);

  readOnlyUndefined = evalMinimalConfig {
    imports = [ ./read-only.nix ];
  };

  readOnlyBad = evalMinimalConfig {
    imports = [ ./read-only.nix ];
    botpkgs.pkgs = { };
  };

  readOnly = evalMinimalConfig {
    imports = [ ./read-only.nix ];
    botpkgs.pkgs = pkgs;
  };

  readOnlyBadConfig = evalMinimalConfig {
    imports = [ ./read-only.nix ];
    botpkgs.pkgs = pkgs;
    botpkgs.config.allowUnfree = true; # do in pkgs instead!
  };

  readOnlyBadOverlays = evalMinimalConfig {
    imports = [ ./read-only.nix ];
    botpkgs.pkgs = pkgs;
    botpkgs.overlays = [ (_: _: {}) ]; # do in pkgs instead!
  };

  readOnlyBadHostPlatform = evalMinimalConfig {
    imports = [ ./read-only.nix ];
    botpkgs.pkgs = pkgs;
    botpkgs.hostPlatform = "foo-linux"; # do in pkgs instead!
  };

  readOnlyBadBuildPlatform = evalMinimalConfig {
    imports = [ ./read-only.nix ];
    botpkgs.pkgs = pkgs;
    botpkgs.buildPlatform = "foo-linux"; # do in pkgs instead!
  };

  throws = x: ! (builtins.tryEval x).success;

in
lib.recurseIntoAttrs {
  invokeNixpkgsSimple =
    (eval {
      botpkgs.system = stdenv.hostPlatform.system;
    })._module.args.pkgs.hello;
  assertions =
    assert withHost._module.args.pkgs.stdenv.hostPlatform.system == "aarch64-linux";
    assert withHost._module.args.pkgs.stdenv.buildPlatform.system == "aarch64-linux";
    assert withHostAndBuild._module.args.pkgs.stdenv.hostPlatform.system == "aarch64-linux";
    assert withHostAndBuild._module.args.pkgs.stdenv.buildPlatform.system == "aarch64-darwin";
    assert builtins.trace (lib.head (getErrors ambiguous))
      getErrors ambiguous ==
        [''
          Your system configures botpkgs with the platform parameters:
          botpkgs.hostPlatform, with values defined in:
            - repeat.nix
            - ambiguous.nix
          botpkgs.buildPlatform, with values defined in:
            - ambiguous.nix

          However, it also defines the legacy options:
          botpkgs.system, with values defined in:
            - ambiguous.nix
          botpkgs.localSystem, with values defined in:
            - ambiguous.nix
          botpkgs.crossSystem, with values defined in:
            - ambiguous.nix

          For a future proof system configuration, we recommend to remove
          the legacy definitions.
        ''];
    assert getErrors {
        botpkgs.localSystem = pkgs.stdenv.hostPlatform;
        botpkgs.hostPlatform = pkgs.stdenv.hostPlatform;
        botpkgs.pkgs = pkgs;
      } == [];


    # Tests for the read-only.nix module
    assert readOnly._module.args.pkgs.stdenv.hostPlatform.system == pkgs.stdenv.hostPlatform.system;
    assert throws readOnlyBad._module.args.pkgs.stdenv;
    assert throws readOnlyUndefined._module.args.pkgs.stdenv;
    assert throws readOnlyBadConfig._module.args.pkgs.stdenv;
    assert throws readOnlyBadOverlays._module.args.pkgs.stdenv;
    assert throws readOnlyBadHostPlatform._module.args.pkgs.stdenv;
    assert throws readOnlyBadBuildPlatform._module.args.pkgs.stdenv;
    # read-only.nix does not provide legacy options, for the sake of simplicity
    # If you're bothered by this, upgrade your configs to use the new *Platform
    # options.
    assert !readOnly.options.botpkgs?system;
    assert !readOnly.options.botpkgs?localSystem;
    assert !readOnly.options.botpkgs?crossSystem;

    pkgs.emptyFile;
}
