{ config, lib, pkgs, ... }:
with lib;

let
  cfg = config.services.journalwatch;
  user = "journalwatch";
  # for journal access
  group = "systemd-journal";
  dataDir = "/var/lib/${user}";

  journalwatchConfig = pkgs.writeText "config" (''
    # (File Generated by Botnix journalwatch module.)
    [DEFAULT]
    mail_binary = ${cfg.mailBinary}
    priority = ${toString cfg.priority}
    mail_from = ${cfg.mailFrom}
  ''
  + optionalString (cfg.mailTo != null) ''
    mail_to = ${cfg.mailTo}
  ''
  + cfg.extraConfig);

  journalwatchPatterns = pkgs.writeText "patterns" ''
    # (File Generated by Botnix journalwatch module.)

    ${mkPatterns cfg.filterBlocks}
  '';

  # empty line at the end needed to to separate the blocks
  mkPatterns = filterBlocks: concatStringsSep "\n" (map (block: ''
    ${block.match}
    ${block.filters}

  '') filterBlocks);

  # can't use joinSymlinks directly, because when we point $XDG_CONFIG_HOME
  # to the /nix/store path, we still need the subdirectory "journalwatch" inside that
  # to match journalwatch's expectations
  journalwatchConfigDir = pkgs.runCommand "journalwatch-config"
    { preferLocalBuild = true; allowSubstitutes = false; }
    ''
      mkdir -p $out/journalwatch
      ln -sf ${journalwatchConfig} $out/journalwatch/config
      ln -sf ${journalwatchPatterns} $out/journalwatch/patterns
    '';


in {
  options = {
    services.journalwatch = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = lib.mdDoc ''
          If enabled, periodically check the journal with journalwatch and report the results by mail.
        '';
      };

      priority = mkOption {
        type = types.int;
        default = 6;
        description = lib.mdDoc ''
          Lowest priority of message to be considered.
          A value between 7 ("debug"), and 0 ("emerg"). Defaults to 6 ("info").
          If you don't care about anything with "info" priority, you can reduce
          this to e.g. 5 ("notice") to considerably reduce the amount of
          messages without needing many {option}`filterBlocks`.
        '';
      };

      # HACK: this is a workaround for journalwatch's usage of socket.getfqdn() which always returns localhost if
      # there's an alias for the localhost on a separate line in /etc/hosts, or take for ages if it's not present and
      # then return something right-ish in the direction of /etc/hostname. Just bypass it completely.
      mailFrom = mkOption {
        type = types.str;
        default = "journalwatch@${config.networking.hostName}";
        defaultText = literalExpression ''"journalwatch@''${config.networking.hostName}"'';
        description = lib.mdDoc ''
          Mail address to send journalwatch reports from.
        '';
      };

      mailTo = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = lib.mdDoc ''
          Mail address to send journalwatch reports to.
        '';
      };

      mailBinary = mkOption {
        type = types.path;
        default = "/run/wrappers/bin/sendmail";
        description = lib.mdDoc ''
          Sendmail-compatible binary to be used to send the messages.
        '';
      };

      extraConfig = mkOption {
        type = types.str;
        default = "";
        description = lib.mdDoc ''
          Extra lines to be added verbatim to the journalwatch/config configuration file.
          You can add any commandline argument to the config, without the '--'.
          See `journalwatch --help` for all arguments and their description.
          '';
      };

      filterBlocks = mkOption {
        type = types.listOf (types.submodule {
          options = {
           match = mkOption {
              type = types.str;
              example = "SYSLOG_IDENTIFIER = systemd";
              description = lib.mdDoc ''
                Syntax: `field = value`
                Specifies the log entry `field` this block should apply to.
                If the `field` of a message matches this `value`,
                this patternBlock's {option}`filters` are applied.
                If `value` starts and ends with a slash, it is interpreted as
                an extended python regular expression, if not, it's an exact match.
                The journal fields are explained in systemd.journal-fields(7).
              '';
            };

            filters = mkOption {
              type = types.str;
              example = ''
                (Stopped|Stopping|Starting|Started) .*
                (Reached target|Stopped target) .*
              '';
              description = lib.mdDoc ''
                The filters to apply on all messages which satisfy {option}`match`.
                Any of those messages that match any specified filter will be removed from journalwatch's output.
                Each filter is an extended Python regular expression.
                You can specify multiple filters and separate them by newlines.
                Lines starting with '#' are comments. Inline-comments are not permitted.
              '';
            };
          };
        });

        example = [
          # examples taken from upstream
          {
            match = "_SYSTEMD_UNIT = systemd-logind.service";
            filters = ''
              New session [a-z]?\d+ of user \w+\.
              Removed session [a-z]?\d+\.
            '';
          }

          {
            match = "SYSLOG_IDENTIFIER = /(CROND|crond)/";
            filters = ''
              pam_unix\(crond:session\): session (opened|closed) for user \w+
              \(\w+\) CMD .*
            '';
          }
        ];

        # another example from upstream.
        # very useful on priority = 6, and required as journalwatch throws an error when no pattern is defined at all.
        default = [
          {
            match = "SYSLOG_IDENTIFIER = systemd";
            filters = ''
              (Stopped|Stopping|Starting|Started) .*
              (Created slice|Removed slice) user-\d*\.slice\.
              Received SIGRTMIN\+24 from PID .*
              (Reached target|Stopped target) .*
              Startup finished in \d*ms\.
            '';
          }
        ];


        description = lib.mdDoc ''
          filterBlocks can be defined to blacklist journal messages which are not errors.
          Each block matches on a log entry field, and the filters in that block then are matched
          against all messages with a matching log entry field.

          All messages whose PRIORITY is at least 6 (INFO) are processed by journalwatch.
          If you don't specify any filterBlocks, PRIORITY is reduced to 5 (NOTICE) by default.

          All regular expressions are extended Python regular expressions, for details
          see: http://doc.pyschools.com/html/regex.html
        '';
      };

      interval = mkOption {
        type = types.str;
        default = "hourly";
        description = lib.mdDoc ''
          How often to run journalwatch.

          The format is described in systemd.time(7).
        '';
      };
      accuracy = mkOption {
        type = types.str;
        default = "10min";
        description = lib.mdDoc ''
          The time window around the interval in which the journalwatch run will be scheduled.

          The format is described in systemd.time(7).
        '';
      };
    };
  };

  config = mkIf cfg.enable {

    users.users.${user} = {
      isSystemUser = true;
      home = dataDir;
      group = group;
    };

    systemd.tmpfiles.rules = [
      # present since Botnix 19.09: remove old stateful symlink join directory,
      # which has been replaced with the journalwatchConfigDir store path
      "R ${dataDir}/config"
    ];

    systemd.services.journalwatch = {

      environment = {
        # journalwatch stores the last processed timpestamp here
        # the share subdirectory is historic now that config home lives in /nix/store,
        # but moving this in a backwards-compatible way is much more work than what's justified
        # for cleaning that up.
        XDG_DATA_HOME = "${dataDir}/share";
        XDG_CONFIG_HOME = journalwatchConfigDir;
      };
      serviceConfig = {
        User = user;
        Group = group;
        Type = "oneshot";
        # requires a relative directory name to create beneath /var/lib
        StateDirectory = user;
        StateDirectoryMode = "0750";
        ExecStart = "${pkgs.python3Packages.journalwatch}/bin/journalwatch mail";
        # lowest CPU and IO priority, but both still in best-effort class to prevent starvation
        Nice=19;
        IOSchedulingPriority=7;
      };
    };

    systemd.timers.journalwatch = {
      description = "Periodic journalwatch run";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.interval;
        AccuracySec = cfg.accuracy;
        Persistent = true;
      };
    };

  };

  meta = {
    maintainers = with lib.maintainers; [ florianjacob ];
  };
}
