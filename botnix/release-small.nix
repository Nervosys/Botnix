# This jobset is used to generate a Botnix channel that contains a
# small subset of Nixpkgs, mostly useful for servers that need fast
# security updates.
#
# Individual jobs can be tested by running:
#
#   nix-build botnix/release-small.nix -A <jobname>
#
{ nixpkgs ? { outPath = (import ../lib).cleanSource ./..; revCount = 56789; shortRev = "gfedcba"; }
, stableBranch ? false
, supportedSystems ? [ "aarch64-linux" "x86_64-linux" ] # no i686-linux
}:

let

  nixpkgsSrc = nixpkgs; # urgh

  pkgs = import ./.. { system = "x86_64-linux"; };

  lib = pkgs.lib;

  botnix' = import ./release.nix {
    inherit stableBranch supportedSystems;
    nixpkgs = nixpkgsSrc;
  };

  nixpkgs' = builtins.removeAttrs (import ../pkgs/top-level/release.nix {
    inherit supportedSystems;
    nixpkgs = nixpkgsSrc;
  }) [ "unstable" ];

in rec {

  botnix = {
    inherit (botnix') channel manual options iso_minimal amazonImage dummy;
    tests = {
      inherit (botnix'.tests)
        acme
        containers-imperative
        containers-ip
        firewall
        ipv6
        login
        misc
        nat
        nfs3
        openssh
        php
        predictable-interface-names
        proxy
        simple;
      installer = {
        inherit (botnix'.tests.installer)
          lvm
          separateBoot
          simple;
      };
      boot = {
        inherit (botnix'.tests.boot)
          biosCdrom
          uefiCdrom;
      };
    };
  };

  nixpkgs = {
    inherit (nixpkgs')
      apacheHttpd
      cmake
      cryptsetup
      emacs
      gettext
      git
      imagemagick
      jdk
      linux
      mariadb
      nginx
      nodejs
      openssh
      php
      postgresql
      python
      rsyslog
      stdenv
      subversion
      tarball
      vim
      tests-stdenv-gcc-stageCompare;
  };

  tested = let
    onSupported = x: map (system: "${x}.${system}") supportedSystems;
    onSystems = systems: x: map (system: "${x}.${system}")
      (pkgs.lib.intersectLists systems supportedSystems);
  in pkgs.releaseTools.aggregate {
    name = "botnix-${botnix.channel.version}";
    meta = {
      description = "Release-critical builds for the Botnix channel";
      maintainers = [ lib.maintainers.eelco ];
    };
    constituents = lib.flatten [
      [
        "botnix.channel"
        "nixpkgs.tarball"
      ]
      (map (onSystems [ "x86_64-linux" ]) [
        "botnix.tests.boot.biosCdrom"
        "botnix.tests.installer.lvm"
        "botnix.tests.installer.separateBoot"
        "botnix.tests.installer.simple"
      ])
      (map onSupported [
        "botnix.dummy"
        "botnix.iso_minimal"
        "botnix.amazonImage"
        "botnix.manual"
        "botnix.tests.acme"
        "botnix.tests.boot.uefiCdrom"
        "botnix.tests.containers-imperative"
        "botnix.tests.containers-ip"
        "botnix.tests.firewall"
        "botnix.tests.ipv6"
        "botnix.tests.login"
        "botnix.tests.misc"
        "botnix.tests.nat.firewall"
        "botnix.tests.nat.standalone"
        "botnix.tests.nfs3.simple"
        "botnix.tests.openssh"
        "botnix.tests.php.fpm"
        "botnix.tests.php.pcre"
        "botnix.tests.predictable-interface-names.predictable"
        "botnix.tests.predictable-interface-names.predictableNetworkd"
        "botnix.tests.predictable-interface-names.unpredictable"
        "botnix.tests.predictable-interface-names.unpredictableNetworkd"
        "botnix.tests.proxy"
        "botnix.tests.simple"
        "nixpkgs.jdk"
        "nixpkgs.tests-stdenv-gcc-stageCompare"
      ])
    ];
  };

}
