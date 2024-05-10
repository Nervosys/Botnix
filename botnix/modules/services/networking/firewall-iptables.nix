/* This module enables a simple firewall.

   The firewall can be customised in arbitrary ways by setting
   ‘networking.firewall.extraCommands’.  For modularity, the firewall
   uses several chains:

   - ‘botnix-fw’ is the main chain for input packet processing.

   - ‘botnix-fw-accept’ is called for accepted packets.  If you want
   additional logging, or want to reject certain packets anyway, you
   can insert rules at the start of this chain.

   - ‘botnix-fw-log-refuse’ and ‘botnix-fw-refuse’ are called for
   refused packets.  (The former jumps to the latter after logging
   the packet.)  If you want additional logging, or want to accept
   certain packets anyway, you can insert rules at the start of
   this chain.

   - ‘botnix-fw-rpfilter’ is used as the main chain in the mangle table,
   called from the built-in ‘PREROUTING’ chain.  If the kernel
   supports it and `cfg.checkReversePath` is set this chain will
   perform a reverse path filter test.

   - ‘botnix-drop’ is used while reloading the firewall in order to drop
   all traffic.  Since reloading isn't implemented in an atomic way
   this'll prevent any traffic from leaking through while reloading
   the firewall.  However, if the reloading fails, the ‘firewall-stop’
   script will be called which in return will effectively disable the
   complete firewall (in the default configuration).

*/

{ config, lib, pkgs, ... }:

with lib;

let

  cfg = config.networking.firewall;

  inherit (config.boot.kernelPackages) kernel;

  kernelHasRPFilter = ((kernel.config.isEnabled or (x: false)) "IP_NF_MATCH_RPFILTER") || (kernel.features.netfilterRPFilter or false);

  helpers = import ./helpers.nix { inherit config lib; };

  writeShScript = name: text:
    let
      dir = pkgs.writeScriptBin name ''
        #! ${pkgs.runtimeShell} -e
        ${text}
      '';
    in
    "${dir}/bin/${name}";

  startScript = writeShScript "firewall-start" ''
    ${helpers}

    # Flush the old firewall rules.  !!! Ideally, updating the
    # firewall would be atomic.  Apparently that's possible
    # with iptables-restore.
    ip46tables -D INPUT -j botnix-fw 2> /dev/null || true
    for chain in botnix-fw botnix-fw-accept botnix-fw-log-refuse botnix-fw-refuse; do
      ip46tables -F "$chain" 2> /dev/null || true
      ip46tables -X "$chain" 2> /dev/null || true
    done


    # The "botnix-fw-accept" chain just accepts packets.
    ip46tables -N botnix-fw-accept
    ip46tables -A botnix-fw-accept -j ACCEPT


    # The "botnix-fw-refuse" chain rejects or drops packets.
    ip46tables -N botnix-fw-refuse

    ${if cfg.rejectPackets then ''
      # Send a reset for existing TCP connections that we've
      # somehow forgotten about.  Send ICMP "port unreachable"
      # for everything else.
      ip46tables -A botnix-fw-refuse -p tcp ! --syn -j REJECT --reject-with tcp-reset
      ip46tables -A botnix-fw-refuse -j REJECT
    '' else ''
      ip46tables -A botnix-fw-refuse -j DROP
    ''}


    # The "botnix-fw-log-refuse" chain performs logging, then
    # jumps to the "botnix-fw-refuse" chain.
    ip46tables -N botnix-fw-log-refuse

    ${optionalString cfg.logRefusedConnections ''
      ip46tables -A botnix-fw-log-refuse -p tcp --syn -j LOG --log-level info --log-prefix "refused connection: "
    ''}
    ${optionalString (cfg.logRefusedPackets && !cfg.logRefusedUnicastsOnly) ''
      ip46tables -A botnix-fw-log-refuse -m pkttype --pkt-type broadcast \
        -j LOG --log-level info --log-prefix "refused broadcast: "
      ip46tables -A botnix-fw-log-refuse -m pkttype --pkt-type multicast \
        -j LOG --log-level info --log-prefix "refused multicast: "
    ''}
    ip46tables -A botnix-fw-log-refuse -m pkttype ! --pkt-type unicast -j botnix-fw-refuse
    ${optionalString cfg.logRefusedPackets ''
      ip46tables -A botnix-fw-log-refuse \
        -j LOG --log-level info --log-prefix "refused packet: "
    ''}
    ip46tables -A botnix-fw-log-refuse -j botnix-fw-refuse


    # The "botnix-fw" chain does the actual work.
    ip46tables -N botnix-fw

    # Clean up rpfilter rules
    ip46tables -t mangle -D PREROUTING -j botnix-fw-rpfilter 2> /dev/null || true
    ip46tables -t mangle -F botnix-fw-rpfilter 2> /dev/null || true
    ip46tables -t mangle -X botnix-fw-rpfilter 2> /dev/null || true

    ${optionalString (kernelHasRPFilter && (cfg.checkReversePath != false)) ''
      # Perform a reverse-path test to refuse spoofers
      # For now, we just drop, as the mangle table doesn't have a log-refuse yet
      ip46tables -t mangle -N botnix-fw-rpfilter 2> /dev/null || true
      ip46tables -t mangle -A botnix-fw-rpfilter -m rpfilter --validmark ${optionalString (cfg.checkReversePath == "loose") "--loose"} -j RETURN

      # Allows this host to act as a DHCP4 client without first having to use APIPA
      iptables -t mangle -A botnix-fw-rpfilter -p udp --sport 67 --dport 68 -j RETURN

      # Allows this host to act as a DHCPv4 server
      iptables -t mangle -A botnix-fw-rpfilter -s 0.0.0.0 -d 255.255.255.255 -p udp --sport 68 --dport 67 -j RETURN

      ${optionalString cfg.logReversePathDrops ''
        ip46tables -t mangle -A botnix-fw-rpfilter -j LOG --log-level info --log-prefix "rpfilter drop: "
      ''}
      ip46tables -t mangle -A botnix-fw-rpfilter -j DROP

      ip46tables -t mangle -A PREROUTING -j botnix-fw-rpfilter
    ''}

    # Accept all traffic on the trusted interfaces.
    ${flip concatMapStrings cfg.trustedInterfaces (iface: ''
      ip46tables -A botnix-fw -i ${iface} -j botnix-fw-accept
    '')}

    # Accept packets from established or related connections.
    ip46tables -A botnix-fw -m conntrack --ctstate ESTABLISHED,RELATED -j botnix-fw-accept

    # Accept connections to the allowed TCP ports.
    ${concatStrings (mapAttrsToList (iface: cfg:
      concatMapStrings (port:
        ''
          ip46tables -A botnix-fw -p tcp --dport ${toString port} -j botnix-fw-accept ${optionalString (iface != "default") "-i ${iface}"}
        ''
      ) cfg.allowedTCPPorts
    ) cfg.allInterfaces)}

    # Accept connections to the allowed TCP port ranges.
    ${concatStrings (mapAttrsToList (iface: cfg:
      concatMapStrings (rangeAttr:
        let range = toString rangeAttr.from + ":" + toString rangeAttr.to; in
        ''
          ip46tables -A botnix-fw -p tcp --dport ${range} -j botnix-fw-accept ${optionalString (iface != "default") "-i ${iface}"}
        ''
      ) cfg.allowedTCPPortRanges
    ) cfg.allInterfaces)}

    # Accept packets on the allowed UDP ports.
    ${concatStrings (mapAttrsToList (iface: cfg:
      concatMapStrings (port:
        ''
          ip46tables -A botnix-fw -p udp --dport ${toString port} -j botnix-fw-accept ${optionalString (iface != "default") "-i ${iface}"}
        ''
      ) cfg.allowedUDPPorts
    ) cfg.allInterfaces)}

    # Accept packets on the allowed UDP port ranges.
    ${concatStrings (mapAttrsToList (iface: cfg:
      concatMapStrings (rangeAttr:
        let range = toString rangeAttr.from + ":" + toString rangeAttr.to; in
        ''
          ip46tables -A botnix-fw -p udp --dport ${range} -j botnix-fw-accept ${optionalString (iface != "default") "-i ${iface}"}
        ''
      ) cfg.allowedUDPPortRanges
    ) cfg.allInterfaces)}

    # Optionally respond to ICMPv4 pings.
    ${optionalString cfg.allowPing ''
      iptables -w -A botnix-fw -p icmp --icmp-type echo-request ${optionalString (cfg.pingLimit != null)
        "-m limit ${cfg.pingLimit} "
      }-j botnix-fw-accept
    ''}

    ${optionalString config.networking.enableIPv6 ''
      # Accept all ICMPv6 messages except redirects and node
      # information queries (type 139).  See RFC 4890, section
      # 4.4.
      ip6tables -A botnix-fw -p icmpv6 --icmpv6-type redirect -j DROP
      ip6tables -A botnix-fw -p icmpv6 --icmpv6-type 139 -j DROP
      ip6tables -A botnix-fw -p icmpv6 -j botnix-fw-accept

      # Allow this host to act as a DHCPv6 client
      ip6tables -A botnix-fw -d fe80::/64 -p udp --dport 546 -j botnix-fw-accept
    ''}

    ${cfg.extraCommands}

    # Reject/drop everything else.
    ip46tables -A botnix-fw -j botnix-fw-log-refuse


    # Enable the firewall.
    ip46tables -A INPUT -j botnix-fw
  '';

  stopScript = writeShScript "firewall-stop" ''
    ${helpers}

    # Clean up in case reload fails
    ip46tables -D INPUT -j botnix-drop 2>/dev/null || true

    # Clean up after added ruleset
    ip46tables -D INPUT -j botnix-fw 2>/dev/null || true

    ${optionalString (kernelHasRPFilter && (cfg.checkReversePath != false)) ''
      ip46tables -t mangle -D PREROUTING -j botnix-fw-rpfilter 2>/dev/null || true
    ''}

    ${cfg.extraStopCommands}
  '';

  reloadScript = writeShScript "firewall-reload" ''
    ${helpers}

    # Create a unique drop rule
    ip46tables -D INPUT -j botnix-drop 2>/dev/null || true
    ip46tables -F botnix-drop 2>/dev/null || true
    ip46tables -X botnix-drop 2>/dev/null || true
    ip46tables -N botnix-drop
    ip46tables -A botnix-drop -j DROP

    # Don't allow traffic to leak out until the script has completed
    ip46tables -A INPUT -j botnix-drop

    ${cfg.extraStopCommands}

    if ${startScript}; then
      ip46tables -D INPUT -j botnix-drop 2>/dev/null || true
    else
      echo "Failed to reload firewall... Stopping"
      ${stopScript}
      exit 1
    fi
  '';

in

{

  options = {

    networking.firewall = {
      extraCommands = mkOption {
        type = types.lines;
        default = "";
        example = "iptables -A INPUT -p icmp -j ACCEPT";
        description = lib.mdDoc ''
          Additional shell commands executed as part of the firewall
          initialisation script.  These are executed just before the
          final "reject" firewall rule is added, so they can be used
          to allow packets that would otherwise be refused.

          This option only works with the iptables based firewall.
        '';
      };

      extraStopCommands = mkOption {
        type = types.lines;
        default = "";
        example = "iptables -P INPUT ACCEPT";
        description = lib.mdDoc ''
          Additional shell commands executed as part of the firewall
          shutdown script.  These are executed just after the removal
          of the Botnix input rule, or if the service enters a failed
          state.

          This option only works with the iptables based firewall.
        '';
      };
    };

  };

  # FIXME: Maybe if `enable' is false, the firewall should still be
  # built but not started by default?
  config = mkIf (cfg.enable && config.networking.nftables.enable == false) {

    assertions = [
      # This is approximately "checkReversePath -> kernelHasRPFilter",
      # but the checkReversePath option can include non-boolean
      # values.
      {
        assertion = cfg.checkReversePath == false || kernelHasRPFilter;
        message = "This kernel does not support rpfilter";
      }
    ];

    environment.systemPackages = [ pkgs.botnix-firewall-tool ];
    networking.firewall.checkReversePath = mkIf (!kernelHasRPFilter) (mkDefault false);

    systemd.services.firewall = {
      description = "Firewall";
      wantedBy = [ "sysinit.target" ];
      wants = [ "network-pre.target" ];
      after = [ "systemd-modules-load.service" ];
      before = [ "network-pre.target" "shutdown.target" ];
      conflicts = [ "shutdown.target" ];

      path = [ cfg.package ] ++ cfg.extraPackages;

      # FIXME: this module may also try to load kernel modules, but
      # containers don't have CAP_SYS_MODULE.  So the host system had
      # better have all necessary modules already loaded.
      unitConfig.ConditionCapability = "CAP_NET_ADMIN";
      unitConfig.DefaultDependencies = false;

      reloadIfChanged = true;

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "@${startScript} firewall-start";
        ExecReload = "@${reloadScript} firewall-reload";
        ExecStop = "@${stopScript} firewall-stop";
      };
    };

  };

}
