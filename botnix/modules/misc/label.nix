{ config, lib, ... }:

with lib;

let
  cfg = config.system.botnix;
in

{

  options.system = {

    botnix.label = mkOption {
      type = types.strMatching "[a-zA-Z0-9:_\\.-]*";
      description = lib.mdDoc ''
        Botnix version name to be used in the names of generated
        outputs and boot labels.

        If you ever wanted to influence the labels in your GRUB menu,
        this is the option for you.

        It can only contain letters, numbers and the following symbols:
        `:`, `_`, `.` and `-`.

        The default is {option}`system.botnix.tags` separated by
        "-" + "-" + {env}`NIXOS_LABEL_VERSION` environment
        variable (defaults to the value of
        {option}`system.botnix.version`).

        Can be overridden by setting {env}`NIXOS_LABEL`.

        Useful for not loosing track of configurations built from different
        botnix branches/revisions, e.g.:

        ```
        #!/bin/sh
        today=`date +%Y%m%d`
        branch=`(cd nixpkgs ; git branch 2>/dev/null | sed -n '/^\* / { s|^\* ||; p; }')`
        revision=`(cd nixpkgs ; git rev-parse HEAD)`
        export NIXOS_LABEL_VERSION="$today.$branch-''${revision:0:7}"
        botnix-rebuild switch
        ```
      '';
    };

    botnix.tags = mkOption {
      type = types.listOf types.str;
      default = [];
      example = [ "with-xen" ];
      description = lib.mdDoc ''
        Strings to prefix to the default
        {option}`system.botnix.label`.

        Useful for not loosing track of configurations built with
        different options, e.g.:

        ```
        {
          system.botnix.tags = [ "with-xen" ];
          virtualisation.xen.enable = true;
        }
        ```
      '';
    };

  };

  config = {
    # This is set here rather than up there so that changing it would
    # not rebuild the manual
    system.botnix.label = mkDefault (maybeEnv "NIXOS_LABEL"
                                             (concatStringsSep "-" ((sort (x: y: x < y) cfg.tags)
                                              ++ [ (maybeEnv "NIXOS_LABEL_VERSION" cfg.version) ])));
  };

}
