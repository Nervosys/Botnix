{ config, lib, pkgs, options }:

with lib;

let
  cfg = config.services.prometheus.exporters.restic;
in
{
  port = 9753;
  extraOpts = {
    repository = mkOption {
      type = types.str;
      description = lib.mdDoc ''
        URI pointing to the repository to monitor.
      '';
      example = "sftp:backup@192.168.1.100:/backups/example";
    };

    passwordFile = mkOption {
      type = types.path;
      description = lib.mdDoc ''
        File containing the password to the repository.
      '';
      example = "/etc/botnix/restic-password";
    };

    environmentFile = mkOption {
      type = with types; nullOr path;
      default = null;
      description = lib.mdDoc ''
        File containing the credentials to access the repository, in the
        format of an EnvironmentFile as described by systemd.exec(5)
      '';
    };

    refreshInterval = mkOption {
      type = types.ints.unsigned;
      default = 60;
      description = lib.mdDoc ''
        Refresh interval for the metrics in seconds.
        Computing the metrics is an expensive task, keep this value as high as possible.
      '';
    };

    rcloneOptions = mkOption {
      type = with types; attrsOf (oneOf [ str bool ]);
      default = { };
      description = lib.mdDoc ''
        Options to pass to rclone to control its behavior.
        See <https://rclone.org/docs/#options> for
        available options. When specifying option names, strip the
        leading `--`. To set a flag such as
        `--drive-use-trash`, which does not take a value,
        set the value to the Boolean `true`.
      '';
    };

    rcloneConfig = mkOption {
      type = with types; attrsOf (oneOf [ str bool ]);
      default = { };
      description = lib.mdDoc ''
        Configuration for the rclone remote being used for backup.
        See the remote's specific options under rclone's docs at
        <https://rclone.org/docs/>. When specifying
        option names, use the "config" name specified in the docs.
        For example, to set `--b2-hard-delete` for a B2
        remote, use `hard_delete = true` in the
        attribute set.

        ::: {.warning}
        Secrets set in here will be world-readable in the Nix
        store! Consider using the {option}`rcloneConfigFile`
        option instead to specify secret values separately. Note that
        options set here will override those set in the config file.
        :::
      '';
    };

    rcloneConfigFile = mkOption {
      type = with types; nullOr path;
      default = null;
      description = lib.mdDoc ''
        Path to the file containing rclone configuration. This file
        must contain configuration for the remote specified in this backup
        set and also must be readable by root.

        ::: {.caution}
        Options set in `rcloneConfig` will override those set in this
        file.
        :::
      '';
    };
  };

  serviceOpts = {
    serviceConfig = {
      ExecStart = ''
        ${pkgs.prometheus-restic-exporter}/bin/restic-exporter.py \
          ${concatStringsSep " \\\n  " cfg.extraFlags}
      '';
      EnvironmentFile = mkIf (cfg.environmentFile != null) cfg.environmentFile;
    };
    environment =
      let
        rcloneRemoteName = builtins.elemAt (splitString ":" cfg.repository) 1;
        rcloneAttrToOpt = v: "RCLONE_" + toUpper (builtins.replaceStrings [ "-" ] [ "_" ] v);
        rcloneAttrToConf = v: "RCLONE_CONFIG_" + toUpper (rcloneRemoteName + "_" + v);
        toRcloneVal = v: if lib.isBool v then lib.boolToString v else v;
      in
      {
        RESTIC_REPO_URL = cfg.repository;
        RESTIC_REPO_PASSWORD_FILE = cfg.passwordFile;
        LISTEN_ADDRESS = cfg.listenAddress;
        LISTEN_PORT = toString cfg.port;
        REFRESH_INTERVAL = toString cfg.refreshInterval;
      }
      // (mapAttrs'
        (name: value:
          nameValuePair (rcloneAttrToOpt name) (toRcloneVal value)
        )
        cfg.rcloneOptions)
      // optionalAttrs (cfg.rcloneConfigFile != null) {
        RCLONE_CONFIG = cfg.rcloneConfigFile;
      }
      // (mapAttrs'
        (name: value:
          nameValuePair (rcloneAttrToConf name) (toRcloneVal value)
        )
        cfg.rcloneConfig);
  };
}
