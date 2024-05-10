# This jobset defines the main Botnix channels (such as botnix-unstable
# and botnix-14.04). The channel is updated every time the ‘tested’ job
# succeeds, and all other jobs have finished (they may fail).

{ botpkgs ? { outPath = (import ../lib).cleanSource ./..; revCount = 56789; shortRev = "gfedcba"; }
, stableBranch ? false
, supportedSystems ? [ "aarch64-linux" "x86_64-linux" ]
, limitedSupportedSystems ? [ ]
}:

let

  nixpkgsSrc = botpkgs; # urgh

  pkgs = import ./.. {};

  removeMaintainers = set: if builtins.isAttrs set
    then if (set.type or "") == "derivation"
      then set // { meta = builtins.removeAttrs (set.meta or {}) [ "maintainers" ]; }
      else pkgs.lib.mapAttrs (n: v: removeMaintainers v) set
    else set;

in rec {

  botnix = removeMaintainers (import ./release.nix {
    inherit stableBranch;
    supportedSystems = supportedSystems ++ limitedSupportedSystems;
    botpkgs = nixpkgsSrc;
  });

  botpkgs = builtins.removeAttrs (removeMaintainers (import ../pkgs/top-level/release.nix {
    inherit supportedSystems;
    botpkgs = nixpkgsSrc;
  })) [ "unstable" ];

  tested =
    let
      onFullSupported = x: map (system: "${x}.${system}") supportedSystems;
      onAllSupported = x: map (system: "${x}.${system}") (supportedSystems ++ limitedSupportedSystems);
      onSystems = systems: x: map (system: "${x}.${system}")
        (pkgs.lib.intersectLists systems (supportedSystems ++ limitedSupportedSystems));
    in pkgs.releaseTools.aggregate {
      name = "botnix-${botnix.channel.version}";
      meta = {
        description = "Release-critical builds for the Botnix channel";
        maintainers = with pkgs.lib.maintainers; [ eelco ];
      };
      constituents = pkgs.lib.concatLists [
        [ "botnix.channel" ]
        (onFullSupported "botnix.dummy")
        (onAllSupported "botnix.iso_minimal")
        (onSystems ["x86_64-linux" "aarch64-linux"] "botnix.amazonImage")
        (onFullSupported "botnix.iso_plasma5")
        (onFullSupported "botnix.iso_gnome")
        (onFullSupported "botnix.manual")
        (onSystems ["x86_64-linux"] "botnix.ova")
        (onSystems ["aarch64-linux"] "botnix.sd_image")
        (onFullSupported "botnix.tests.acme")
        (onSystems ["x86_64-linux"] "botnix.tests.boot.biosCdrom")
        (onSystems ["x86_64-linux"] "botnix.tests.boot.biosUsb")
        (onFullSupported "botnix.tests.boot-stage1")
        (onFullSupported "botnix.tests.boot.uefiCdrom")
        (onFullSupported "botnix.tests.boot.uefiUsb")
        (onFullSupported "botnix.tests.chromium")
        (onFullSupported "botnix.tests.containers-imperative")
        (onFullSupported "botnix.tests.containers-ip")
        (onSystems ["x86_64-linux"] "botnix.tests.docker")
        (onFullSupported "botnix.tests.ecryptfs")
        (onFullSupported "botnix.tests.env")

        # Way too many manual retries required on Hydra.
        #  Apparently it's hard to track down the cause.
        #  So let's depend just on the packages for now.
        #(onFullSupported "botnix.tests.firefox-esr")
        #(onFullSupported "botnix.tests.firefox")
        # Note: only -unwrapped variants have a Hydra job.
        (onFullSupported "botpkgs.firefox-esr-unwrapped")
        (onFullSupported "botpkgs.firefox-unwrapped")

        (onFullSupported "botnix.tests.firewall")
        (onFullSupported "botnix.tests.fontconfig-default-fonts")
        (onFullSupported "botnix.tests.gitlab")
        (onFullSupported "botnix.tests.gnome")
        (onFullSupported "botnix.tests.gnome-xorg")
        (onSystems ["x86_64-linux"] "botnix.tests.hibernate")
        (onFullSupported "botnix.tests.i3wm")
        (onSystems ["x86_64-linux"] "botnix.tests.installer.btrfsSimple")
        (onSystems ["x86_64-linux"] "botnix.tests.installer.btrfsSubvolDefault")
        (onSystems ["x86_64-linux"] "botnix.tests.installer.btrfsSubvolEscape")
        (onSystems ["x86_64-linux"] "botnix.tests.installer.btrfsSubvols")
        (onSystems ["x86_64-linux"] "botnix.tests.installer.luksroot")
        (onSystems ["x86_64-linux"] "botnix.tests.installer.lvm")
        (onSystems ["x86_64-linux"] "botnix.tests.installer.separateBootZfs")
        (onSystems ["x86_64-linux"] "botnix.tests.installer.separateBootFat")
        (onSystems ["x86_64-linux"] "botnix.tests.installer.separateBoot")
        (onSystems ["x86_64-linux"] "botnix.tests.installer.simpleLabels")
        (onSystems ["x86_64-linux"] "botnix.tests.installer.simpleProvided")
        (onSystems ["x86_64-linux"] "botnix.tests.installer.simpleUefiSystemdBoot")
        (onSystems ["x86_64-linux"] "botnix.tests.installer.simple")
        (onSystems ["x86_64-linux"] "botnix.tests.installer.swraid")
        (onSystems ["x86_64-linux"] "botnix.tests.installer.zfsroot")
        (onSystems ["x86_64-linux"] "botnix.tests.botnix-rebuild-specialisations")
        (onFullSupported "botnix.tests.ipv6")
        (onFullSupported "botnix.tests.keymap.azerty")
        (onFullSupported "botnix.tests.keymap.colemak")
        (onFullSupported "botnix.tests.keymap.dvorak")
        (onFullSupported "botnix.tests.keymap.dvorak-programmer")
        (onFullSupported "botnix.tests.keymap.neo")
        (onFullSupported "botnix.tests.keymap.qwertz")
        (onFullSupported "botnix.tests.latestKernel.login")
        (onFullSupported "botnix.tests.lightdm")
        (onFullSupported "botnix.tests.login")
        (onFullSupported "botnix.tests.misc")
        (onFullSupported "botnix.tests.mutableUsers")
        (onFullSupported "botnix.tests.nat.firewall")
        (onFullSupported "botnix.tests.nat.standalone")
        (onFullSupported "botnix.tests.networking.scripted.bond")
        (onFullSupported "botnix.tests.networking.scripted.bridge")
        (onFullSupported "botnix.tests.networking.scripted.dhcpOneIf")
        (onFullSupported "botnix.tests.networking.scripted.dhcpSimple")
        (onFullSupported "botnix.tests.networking.scripted.link")
        (onFullSupported "botnix.tests.networking.scripted.loopback")
        (onFullSupported "botnix.tests.networking.scripted.macvlan")
        (onFullSupported "botnix.tests.networking.scripted.privacy")
        (onFullSupported "botnix.tests.networking.scripted.routes")
        (onFullSupported "botnix.tests.networking.scripted.sit")
        (onFullSupported "botnix.tests.networking.scripted.static")
        (onFullSupported "botnix.tests.networking.scripted.virtual")
        (onFullSupported "botnix.tests.networking.scripted.vlan")
        (onFullSupported "botnix.tests.networking.networkd.bond")
        (onFullSupported "botnix.tests.networking.networkd.bridge")
        (onFullSupported "botnix.tests.networking.networkd.dhcpOneIf")
        (onFullSupported "botnix.tests.networking.networkd.dhcpSimple")
        (onFullSupported "botnix.tests.networking.networkd.link")
        (onFullSupported "botnix.tests.networking.networkd.loopback")
        # Fails nondeterministically (https://github.com/nervosys/Botnix/issues/96709)
        #(onFullSupported "botnix.tests.networking.networkd.macvlan")
        (onFullSupported "botnix.tests.networking.networkd.privacy")
        (onFullSupported "botnix.tests.networking.networkd.routes")
        (onFullSupported "botnix.tests.networking.networkd.sit")
        (onFullSupported "botnix.tests.networking.networkd.static")
        (onFullSupported "botnix.tests.networking.networkd.virtual")
        (onFullSupported "botnix.tests.networking.networkd.vlan")
        (onFullSupported "botnix.tests.systemd-networkd-ipv6-prefix-delegation")
        (onFullSupported "botnix.tests.nfs3.simple")
        (onFullSupported "botnix.tests.nfs4.simple")
        (onSystems ["x86_64-linux"] "botnix.tests.oci-containers.podman")
        (onFullSupported "botnix.tests.openssh")
        (onFullSupported "botnix.tests.pantheon")
        (onFullSupported "botnix.tests.php.fpm")
        (onFullSupported "botnix.tests.php.httpd")
        (onFullSupported "botnix.tests.php.pcre")
        (onFullSupported "botnix.tests.plasma5")
        (onSystems ["x86_64-linux"] "botnix.tests.podman")
        (onFullSupported "botnix.tests.predictable-interface-names.predictableNetworkd")
        (onFullSupported "botnix.tests.predictable-interface-names.predictable")
        (onFullSupported "botnix.tests.predictable-interface-names.unpredictableNetworkd")
        (onFullSupported "botnix.tests.predictable-interface-names.unpredictable")
        (onFullSupported "botnix.tests.printing-service")
        (onFullSupported "botnix.tests.printing-socket")
        (onFullSupported "botnix.tests.proxy")
        (onFullSupported "botnix.tests.sddm.default")
        (onFullSupported "botnix.tests.shadow")
        (onFullSupported "botnix.tests.simple")
        (onFullSupported "botnix.tests.sway")
        (onFullSupported "botnix.tests.switchTest")
        (onFullSupported "botnix.tests.udisks2")
        (onFullSupported "botnix.tests.xfce")
        (onFullSupported "botpkgs.emacs")
        (onFullSupported "botpkgs.jdk")
        (onSystems ["x86_64-linux"] "botpkgs.mesa_i686") # i686 sanity check + useful
        ["botpkgs.tarball"]

        # Ensure that botpkgs-check-by-name is available in botnix-unstable,
        # so that a pre-built version can be used in CI for PR's
        # See ../pkgs/test/botpkgs-check-by-name/README.md
        (onSystems ["x86_64-linux"] "botpkgs.tests.botpkgs-check-by-name")
      ];
    };
}
