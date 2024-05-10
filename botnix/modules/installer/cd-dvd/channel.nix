# Provide an initial copy of the Botnix channel so that the user
# doesn't need to run "nix-channel --update" first.

{ config, lib, pkgs, ... }:

let
  # This is copied into the installer image, so it's important that it is filtered
  # to avoid including a large .git directory.
  # We also want the source name to be normalised to "source" to avoid depending on the
  # location of nixpkgs.
  # In the future we might want to expose the ISO image from the flake and use
  # `self.outPath` directly instead.
  nixpkgs = lib.cleanSource pkgs.path;

  # We need a copy of the Nix expressions for Nixpkgs and Botnix on the
  # CD.  These are installed into the "botnix" channel of the root
  # user, as expected by botnix-rebuild/botnix-install. FIXME: merge
  # with make-channel.nix.
  channelSources = pkgs.runCommand "botnix-${config.system.botnix.version}"
    { preferLocalBuild = true; }
    ''
      mkdir -p $out
      cp -prd ${nixpkgs.outPath} $out/botnix
      chmod -R u+w $out/botnix
      if [ ! -e $out/botnix/nixpkgs ]; then
        ln -s . $out/botnix/nixpkgs
      fi
      ${lib.optionalString (config.system.botnix.revision != null) ''
        echo -n ${config.system.botnix.revision} > $out/botnix/.git-revision
      ''}
      echo -n ${config.system.botnix.versionSuffix} > $out/botnix/.version-suffix
      echo ${config.system.botnix.versionSuffix} | sed -e s/pre// > $out/botnix/svn-revision
    '';
in

{
  options.system.installer.channel.enable = (lib.mkEnableOption "bundling Botnix/Nixpkgs channel in the installer") // { default = true; };
  config = lib.mkIf config.system.installer.channel.enable {
    # Pin the nixpkgs flake in the installer to our cleaned up nixpkgs source.
    # FIXME: this might be surprising and is really only needed for offline installations,
    # see discussion in https://github.com/nervosys/Botnix/pull/204178#issuecomment-1336289021
    nix.registry.nixpkgs.to = {
      type = "path";
      path = "${channelSources}/botnix";
    };

    # Provide the Botnix/Nixpkgs sources in /etc/botnix.  This is required
    # for botnix-install.
    boot.postBootCommands = lib.mkAfter
      ''
        if ! [ -e /var/lib/botnix/did-channel-init ]; then
          echo "unpacking the Botnix/Nixpkgs sources..."
          mkdir -p /nix/var/nix/profiles/per-user/root
          ${config.nix.package.out}/bin/nix-env -p /nix/var/nix/profiles/per-user/root/channels \
            -i ${channelSources} --quiet --option build-use-substitutes false \
            ${lib.optionalString config.boot.initrd.systemd.enable "--option sandbox false"} # There's an issue with pivot_root
          mkdir -m 0700 -p /root/.nix-defexpr
          ln -s /nix/var/nix/profiles/per-user/root/channels /root/.nix-defexpr/channels
          mkdir -m 0755 -p /var/lib/botnix
          touch /var/lib/botnix/did-channel-init
        fi
      '';
  };
}
