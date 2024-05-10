{ system ? builtins.currentSystem
, config ? {}
, networkExpr
}:

let
  nodes = builtins.mapAttrs (vm: module: {
    _file = "${networkExpr}@node-${vm}";
    imports = [ module ];
  }) (import networkExpr);

  pkgs = import ../../../../.. { inherit system config; };

  testing = import ../../../../lib/testing-python.nix {
    inherit system pkgs;
  };

  interactiveDriver = (testing.makeTest { inherit nodes; name = "network"; testScript = "start_all(); join_all();"; }).test.driverInteractive;
in


pkgs.runCommand "botnix-build-vms" { nativeBuildInputs = [ pkgs.makeWrapper ]; } ''
  mkdir -p $out/bin
  ln -s ${interactiveDriver}/bin/botnix-test-driver $out/bin/botnix-test-driver
  ln -s ${interactiveDriver}/bin/botnix-test-driver $out/bin/botnix-run-vms
  wrapProgram $out/bin/botnix-test-driver \
    --add-flags "--interactive"
  wrapProgram $out/bin/botnix-run-vms \
     --set testScript "${pkgs.writeText "start-all" "start_all(); join_all();"}" \
     --add-flags "--no-interactive"
''
