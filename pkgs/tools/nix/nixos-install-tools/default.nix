{
  buildEnv,
  lib,
  man,
  botnix,
  # TODO: replace indirect self-reference by proper self-reference
  #       https://github.com/nervosys/Botnix/pull/119942
  botnix-install-tools,
  runCommand,
  nixosTests,
}:
let
  inherit (botnix {}) config;
  version = config.system.botnix.version;
in
(buildEnv {
  name = "botnix-install-tools-${version}";
  paths = lib.attrValues {
    # See botnix/modules/installer/tools/tools.nix
    inherit (config.system.build)
      botnix-install botnix-generate-config botnix-enter;

    inherit (config.system.build.manual) botnix-configuration-reference-manpage;
  };

  extraOutputsToInstall = ["man"];

  meta = {
    description = "The essential commands from the Botnix installer as a package";
    longDescription = ''
      With this package, you get the commands like botnix-generate-config and
      botnix-install that you would otherwise only find on a Botnix system, such
      as an installer image.

      This way, you can install Botnix using a machine that only has Nix.
    '';
    license = lib.licenses.mit;
    homepage = "https://nixos.org";
    platforms = lib.platforms.linux;
  };

  passthru.tests = {
    botnix-tests = lib.recurseIntoAttrs nixosTests.installer;
    botnix-install-help = runCommand "test-botnix-install-help" {
      nativeBuildInputs = [
        man
        botnix-install-tools
      ];
      meta.description = ''
        Make sure that --help works. It's somewhat non-trivial because it
        requires man.
      '';
    } ''
      botnix-install --help | grep -F 'Botnix Reference Pages'
      botnix-install --help | grep -F 'configuration.nix'
      botnix-generate-config --help | grep -F 'Botnix Reference Pages'
      botnix-generate-config --help | grep -F 'hardware-configuration.nix'

      # FIXME: Tries to call unshare, which it must not do for --help
      # botnix-enter --help | grep -F 'Botnix Reference Pages'

      touch $out
    '';
  };
}).overrideAttrs {
  inherit version;
  pname = "botnix-install-tools";
}
