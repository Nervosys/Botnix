import ./make-test-python.nix ({ pkgs, latestKernel ? false, ... }:

{
  name = "disable-installer-tools";

  nodes.machine =
    { pkgs, lib, ... }:
    {
        system.disableInstallerTools = true;
        boot.enableContainers = false;
        environment.defaultPackages = [];
    };

  testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.wait_until_succeeds("pgrep -f 'agetty.*tty1'")

      with subtest("botnix installer tools should not be included"):
          machine.fail("which botnix-rebuild")
          machine.fail("which botnix-install")
          machine.fail("which botnix-generate-config")
          machine.fail("which botnix-enter")
          machine.fail("which botnix-version")
          machine.fail("which botnix-build-vms")

      with subtest("perl should not be included"):
          machine.fail("which perl")
  '';
})
