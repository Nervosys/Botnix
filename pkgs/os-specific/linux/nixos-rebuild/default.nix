{ callPackage
, substituteAll
, runtimeShell
, coreutils
, gnused
, gnugrep
, jq
, util-linux
, nix
, lib
, nixosTests
, installShellFiles
}:
let
  fallback = import ./../../../../botnix/modules/installer/tools/nix-fallback-paths.nix;
in
substituteAll {
  name = "botnix-rebuild";
  src = ./botnix-rebuild.sh;
  dir = "bin";
  isExecutable = true;
  inherit runtimeShell nix;
  nix_x86_64_linux = fallback.x86_64-linux;
  nix_i686_linux = fallback.i686-linux;
  nix_aarch64_linux = fallback.aarch64-linux;
  path = lib.makeBinPath [ coreutils gnused gnugrep jq util-linux ];
  nativeBuildInputs = [
    installShellFiles
  ];
  postInstall = ''
    installManPage ${./botnix-rebuild.8}

    installShellCompletion \
      --bash ${./_nixos-rebuild}
  '';

  # run some a simple installer tests to make sure botnix-rebuild still works for them
  passthru.tests = {
    install-bootloader = nixosTests.botnix-rebuild-install-bootloader;
    repl = callPackage ./test/repl.nix {};
    simple-installer = nixosTests.installer.simple;
    specialisations = nixosTests.botnix-rebuild-specialisations;
    target-host = nixosTests.botnix-rebuild-target-host;
  };

  meta = {
    description = "Rebuild your Botnix configuration and switch to it, on local hosts and remote.";
    homepage = "https://github.com/nervosys/Botnix/tree/master/pkgs/os-specific/linux/botnix-rebuild";
    license = lib.licenses.mit;
    maintainers = [ lib.maintainers.Profpatsch ];
    mainProgram = "botnix-rebuild";
  };
}
