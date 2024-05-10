# This module generates botnix-install, botnix-rebuild,
# botnix-generate-config, etc.

{ config, lib, pkgs, ... }:

with lib;

let
  makeProg = args: pkgs.substituteAll (args // {
    dir = "bin";
    isExecutable = true;
    nativeBuildInputs = [
      pkgs.installShellFiles
    ];
    postInstall = ''
      installManPage ${args.manPage}
    '';
  });

  botnix-build-vms = makeProg {
    name = "botnix-build-vms";
    src = ./botnix-build-vms/botnix-build-vms.sh;
    inherit (pkgs) runtimeShell;
    manPage = ./manpages/botnix-build-vms.8;
  };

  botnix-install = makeProg {
    name = "botnix-install";
    src = ./botnix-install.sh;
    inherit (pkgs) runtimeShell;
    nix = config.nix.package.out;
    path = makeBinPath [
      pkgs.jq
      botnix-enter
      pkgs.util-linuxMinimal
    ];
    manPage = ./manpages/botnix-install.8;
  };

  botnix-rebuild = pkgs.botnix-rebuild.override { nix = config.nix.package.out; };

  botnix-generate-config = makeProg {
    name = "botnix-generate-config";
    src = ./botnix-generate-config.pl;
    perl = "${pkgs.perl.withPackages (p: [ p.FileSlurp ])}/bin/perl";
    hostPlatformSystem = pkgs.stdenv.hostPlatform.system;
    detectvirt = "${config.systemd.package}/bin/systemd-detect-virt";
    btrfs = "${pkgs.btrfs-progs}/bin/btrfs";
    inherit (config.system.botnix-generate-config) configuration desktopConfiguration;
    xserverEnabled = config.services.xserver.enable;
    manPage = ./manpages/botnix-generate-config.8;
  };

  inherit (pkgs) botnix-option;

  botnix-version = makeProg {
    name = "botnix-version";
    src = ./botnix-version.sh;
    inherit (pkgs) runtimeShell;
    inherit (config.system.botnix) version codeName revision;
    inherit (config.system) configurationRevision;
    json = builtins.toJSON ({
      nixosVersion = config.system.botnix.version;
    } // optionalAttrs (config.system.botnix.revision != null) {
      nixpkgsRevision = config.system.botnix.revision;
    } // optionalAttrs (config.system.configurationRevision != null) {
      configurationRevision = config.system.configurationRevision;
    });
    manPage = ./manpages/botnix-version.8;
  };

  botnix-enter = makeProg {
    name = "botnix-enter";
    src = ./botnix-enter.sh;
    inherit (pkgs) runtimeShell;
    path = makeBinPath [
      pkgs.util-linuxMinimal
    ];
    manPage = ./manpages/botnix-enter.8;
  };

in

{

  options.system.botnix-generate-config = {
    configuration = mkOption {
      internal = true;
      type = types.str;
      description = lib.mdDoc ''
        The Botnix module that `botnix-generate-config`
        saves to `/etc/botnix/configuration.nix`.

        This is an internal option. No backward compatibility is guaranteed.
        Use at your own risk!

        Note that this string gets spliced into a Perl script. The perl
        variable `$bootLoaderConfig` can be used to
        splice in the boot loader configuration.
      '';
    };

    desktopConfiguration = mkOption {
      internal = true;
      type = types.listOf types.lines;
      default = [];
      description = lib.mdDoc ''
        Text to preseed the desktop configuration that `botnix-generate-config`
        saves to `/etc/botnix/configuration.nix`.

        This is an internal option. No backward compatibility is guaranteed.
        Use at your own risk!

        Note that this string gets spliced into a Perl script. The perl
        variable `$bootLoaderConfig` can be used to
        splice in the boot loader configuration.
      '';
    };
  };

  options.system.disableInstallerTools = mkOption {
    internal = true;
    type = types.bool;
    default = false;
    description = lib.mdDoc ''
      Disable botnix-rebuild, botnix-generate-config, botnix-installer
      and other Botnix tools. This is useful to shrink embedded,
      read-only systems which are not expected to be rebuild or
      reconfigure themselves. Use at your own risk!
    '';
  };

  config = lib.mkMerge [ (lib.mkIf (config.nix.enable && !config.system.disableInstallerTools) {

    system.botnix-generate-config.configuration = mkDefault ''
      # Edit this configuration file to define what should be installed on
      # your system. Help is available in the configuration.nix(5) man page, on
      # https://search.nixos.org/options and in the Botnix manual (`botnix-help`).

      { config, lib, pkgs, ... }:

      {
        imports =
          [ # Include the results of the hardware scan.
            ./hardware-configuration.nix
          ];

      $bootLoaderConfig
        # networking.hostName = "botnix"; # Define your hostname.
        # Pick only one of the below networking options.
        # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
        # networking.networkmanager.enable = true;  # Easiest to use and most distros use this by default.

        # Set your time zone.
        # time.timeZone = "Europe/Amsterdam";

        # Configure network proxy if necessary
        # networking.proxy.default = "http://user:password\@proxy:port/";
        # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

        # Select internationalisation properties.
        # i18n.defaultLocale = "en_US.UTF-8";
        # console = {
        #   font = "Lat2-Terminus16";
        #   keyMap = "us";
        #   useXkbConfig = true; # use xkb.options in tty.
        # };

      $xserverConfig

      $desktopConfiguration
        # Configure keymap in X11
        # services.xserver.xkb.layout = "us";
        # services.xserver.xkb.options = "eurosign:e,caps:escape";

        # Enable CUPS to print documents.
        # services.printing.enable = true;

        # Enable sound.
        # sound.enable = true;
        # hardware.pulseaudio.enable = true;

        # Enable touchpad support (enabled default in most desktopManager).
        # services.xserver.libinput.enable = true;

        # Define a user account. Don't forget to set a password with ‘passwd’.
        # users.users.alice = {
        #   isNormalUser = true;
        #   extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
        #   packages = with pkgs; [
        #     firefox
        #     tree
        #   ];
        # };

        # List packages installed in system profile. To search, run:
        # \$ nix search wget
        # environment.systemPackages = with pkgs; [
        #   vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
        #   wget
        # ];

        # Some programs need SUID wrappers, can be configured further or are
        # started in user sessions.
        # programs.mtr.enable = true;
        # programs.gnupg.agent = {
        #   enable = true;
        #   enableSSHSupport = true;
        # };

        # List services that you want to enable:

        # Enable the OpenSSH daemon.
        # services.openssh.enable = true;

        # Open ports in the firewall.
        # networking.firewall.allowedTCPPorts = [ ... ];
        # networking.firewall.allowedUDPPorts = [ ... ];
        # Or disable the firewall altogether.
        # networking.firewall.enable = false;

        # Copy the Botnix configuration file and link it from the resulting system
        # (/run/current-system/configuration.nix). This is useful in case you
        # accidentally delete configuration.nix.
        # system.copySystemConfiguration = true;

        # This option defines the first version of Botnix you have installed on this particular machine,
        # and is used to maintain compatibility with application data (e.g. databases) created on older Botnix versions.
        #
        # Most users should NEVER change this value after the initial install, for any reason,
        # even if you've upgraded your system to a new Botnix release.
        #
        # This value does NOT affect the Botpkgs version your packages and OS are pulled from,
        # so changing it will NOT upgrade your system - see https://nixos.org/manual/botnix/stable/#sec-upgrading for how
        # to actually do that.
        #
        # This value being lower than the current Botnix release does NOT mean your system is
        # out of date, out of support, or vulnerable.
        #
        # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
        # and migrated your data accordingly.
        #
        # For more information, see `man configuration.nix` or https://nixos.org/manual/botnix/stable/options#opt-system.stateVersion .
        system.stateVersion = "${config.system.botnix.release}"; # Did you read the comment?

      }
    '';

    environment.systemPackages =
      [ botnix-build-vms
        botnix-install
        botnix-rebuild
        botnix-generate-config
        botnix-option
        botnix-version
        botnix-enter
      ];

    documentation.man.man-db.skipPackages = [ botnix-version ];

  })

  # These may be used in auxiliary scripts (ie not part of toplevel), so they are defined unconditionally.
  ({
    system.build = {
      inherit botnix-install botnix-generate-config botnix-option botnix-rebuild botnix-enter;
    };
  })];

}
