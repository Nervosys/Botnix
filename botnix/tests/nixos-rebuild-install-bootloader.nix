import ./make-test-python.nix ({ pkgs, ... }: {
  name = "botnix-rebuild-install-bootloader";

  nodes = {
    machine = { lib, pkgs, ... }: {
      imports = [
        ../modules/profiles/installation-device.nix
        ../modules/profiles/base.nix
      ];

      nix.settings = {
        substituters = lib.mkForce [ ];
        hashed-mirrors = null;
        connect-timeout = 1;
      };

      system.includeBuildDependencies = true;

      virtualisation = {
        cores = 2;
        memorySize = 2048;
      };

      virtualisation.useBootLoader = true;
    };
  };

  testScript =
    let
      configFile = pkgs.writeText "configuration.nix" ''
        { lib, pkgs, ... }: {
          imports = [
            ./hardware-configuration.nix
            <botpkgs/botnix/modules/testing/test-instrumentation.nix>
          ];

          boot.loader.grub = {
            enable = true;
            device = "/dev/vda";
            forceInstall = true;
          };

          documentation.enable = false;
        }
      '';

    in
    ''
      machine.start()
      machine.succeed("udevadm settle")
      machine.wait_for_unit("multi-user.target")

      machine.succeed("botnix-generate-config")
      machine.copy_from_host(
          "${configFile}",
          "/etc/botnix/configuration.nix",
      )
      machine.succeed("botnix-rebuild switch")

      # Need to run `botnix-rebuild` twice because the first run will install
      # GRUB anyway
      with subtest("Switch system again and install bootloader"):
          result = machine.succeed("botnix-rebuild switch --install-bootloader")
          # install-grub2.pl messages
          assert "updating GRUB 2 menu..." in result
          assert "installing the GRUB 2 boot loader on /dev/vda..." in result
          # GRUB message
          assert "Installation finished. No error reported." in result
          # at this point we've tested regression #262724, but haven't tested the bootloader itself
          # TODO: figure out how to how to tell the test driver to start the bootloader instead of
          # booting into the kernel directly.
    '';
})
