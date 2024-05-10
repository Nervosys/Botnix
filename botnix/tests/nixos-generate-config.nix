import ./make-test-python.nix ({ lib, ... } : {
  name = "botnix-generate-config";
  meta.maintainers = with lib.maintainers; [ basvandijk ];
  nodes.machine = {
    system.botnix-generate-config.configuration = ''
      # OVERRIDDEN
      { config, pkgs, ... }: {
        imports = [ ./hardware-configuration.nix ];
      $bootLoaderConfig
      $desktopConfiguration
      }
    '';

    system.botnix-generate-config.desktopConfiguration = [''
      # DESKTOP
      services.xserver.displayManager.gdm.enable = true;
      services.xserver.desktopManager.gnome.enable = true;
    ''];
  };
  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")
    machine.succeed("botnix-generate-config")

    # Test if the configuration really is overridden
    machine.succeed("grep 'OVERRIDDEN' /etc/botnix/configuration.nix")

    # Test if desktop configuration really is overridden
    machine.succeed("grep 'DESKTOP' /etc/botnix/configuration.nix")

    # Test of if the Perl variable $bootLoaderConfig is spliced correctly:
    machine.succeed(
        "grep 'boot\\.loader\\.grub\\.enable = true;' /etc/botnix/configuration.nix"
    )

    # Test if the Perl variable $desktopConfiguration is spliced correctly
    machine.succeed(
        "grep 'services\\.xserver\\.desktopManager\\.gnome\\.enable = true;' /etc/botnix/configuration.nix"
    )
  '';
})
