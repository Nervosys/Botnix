{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.virtualisation.virtualbox.host;

  virtualbox = cfg.package.override {
    inherit (cfg) enableHardening headless enableWebService;
    extensionPack = if cfg.enableExtensionPack then pkgs.virtualboxExtpack else null;
  };

  kernelModules = config.boot.kernelPackages.virtualbox.override {
    inherit virtualbox;
  };

in

{
  options.virtualisation.virtualbox.host = {
    enable = mkEnableOption (lib.mdDoc "VirtualBox") // {
      description = lib.mdDoc ''
        Whether to enable VirtualBox.

        ::: {.note}
        In order to pass USB devices from the host to the guests, the user
        needs to be in the `vboxusers` group.
        :::
      '';
    };

    enableExtensionPack = mkEnableOption (lib.mdDoc "VirtualBox extension pack") // {
      description = lib.mdDoc ''
        Whether to install the Oracle Extension Pack for VirtualBox.

        ::: {.important}
        You must set `botpkgs.config.allowUnfree = true` in
        order to use this.  This requires you accept the VirtualBox PUEL.
        :::
      '';
    };

    package = mkPackageOption pkgs "virtualbox" { };

    addNetworkInterface = mkOption {
      type = types.bool;
      default = true;
      description = lib.mdDoc ''
        Automatically set up a vboxnet0 host-only network interface.
      '';
    };

    enableHardening = mkOption {
      type = types.bool;
      default = true;
      description = lib.mdDoc ''
        Enable hardened VirtualBox, which ensures that only the binaries in the
        system path get access to the devices exposed by the kernel modules
        instead of all users in the vboxusers group.

        ::: {.important}
        Disabling this can put your system's security at risk, as local users
        in the vboxusers group can tamper with the VirtualBox device files.
        :::
      '';
    };

    headless = mkOption {
      type = types.bool;
      default = false;
      description = lib.mdDoc ''
        Use VirtualBox installation without GUI and Qt dependency. Useful to enable on servers
        and when virtual machines are controlled only via SSH.
      '';
    };

    enableWebService = mkOption {
      type = types.bool;
      default = false;
      description = lib.mdDoc ''
        Build VirtualBox web service tool (vboxwebsrv) to allow managing VMs via other webpage frontend tools. Useful for headless servers.
      '';
    };
  };

  config = mkIf cfg.enable (mkMerge [{
    warnings = mkIf (pkgs.config.virtualbox.enableExtensionPack or false)
      ["'botpkgs.virtualbox.enableExtensionPack' has no effect, please use 'virtualisation.virtualbox.host.enableExtensionPack'"];
    boot.kernelModules = [ "vboxdrv" "vboxnetadp" "vboxnetflt" ];
    boot.extraModulePackages = [ kernelModules ];
    environment.systemPackages = [ virtualbox ];

    security.wrappers = let
      mkSuid = program: {
        source = "${virtualbox}/libexec/virtualbox/${program}";
        owner = "root";
        group = "vboxusers";
        setuid = true;
      };
      executables = [
        "VBoxHeadless"
        "VBoxNetAdpCtl"
        "VBoxNetDHCP"
        "VBoxNetNAT"
        "VBoxVolInfo"
      ] ++ (lib.optionals (!cfg.headless) [
        "VBoxSDL"
        "VirtualBoxVM"
      ]);
    in mkIf cfg.enableHardening
      (builtins.listToAttrs (map (x: { name = x; value = mkSuid x; }) executables));

    users.groups.vboxusers.gid = config.ids.gids.vboxusers;

    services.udev.extraRules =
      ''
        KERNEL=="vboxdrv",    OWNER="root", GROUP="vboxusers", MODE="0660", TAG+="systemd"
        KERNEL=="vboxdrvu",   OWNER="root", GROUP="root",      MODE="0666", TAG+="systemd"
        KERNEL=="vboxnetctl", OWNER="root", GROUP="vboxusers", MODE="0660", TAG+="systemd"
        SUBSYSTEM=="usb_device", ACTION=="add", RUN+="${virtualbox}/libexec/virtualbox/VBoxCreateUSBNode.sh $major $minor $attr{bDeviceClass}"
        SUBSYSTEM=="usb", ACTION=="add", ENV{DEVTYPE}=="usb_device", RUN+="${virtualbox}/libexec/virtualbox/VBoxCreateUSBNode.sh $major $minor $attr{bDeviceClass}"
        SUBSYSTEM=="usb_device", ACTION=="remove", RUN+="${virtualbox}/libexec/virtualbox/VBoxCreateUSBNode.sh --remove $major $minor"
        SUBSYSTEM=="usb", ACTION=="remove", ENV{DEVTYPE}=="usb_device", RUN+="${virtualbox}/libexec/virtualbox/VBoxCreateUSBNode.sh --remove $major $minor"
      '';

    # Since we lack the right setuid/setcap binaries, set up a host-only network by default.
  } (mkIf cfg.addNetworkInterface {
    systemd.services.vboxnet0 =
      { description = "VirtualBox vboxnet0 Interface";
        requires = [ "dev-vboxnetctl.device" ];
        after = [ "dev-vboxnetctl.device" ];
        wantedBy = [ "network.target" "sys-subsystem-net-devices-vboxnet0.device" ];
        path = [ virtualbox ];
        serviceConfig.RemainAfterExit = true;
        serviceConfig.Type = "oneshot";
        serviceConfig.PrivateTmp = true;
        environment.VBOX_USER_HOME = "/tmp";
        script =
          ''
            if ! [ -e /sys/class/net/vboxnet0 ]; then
              VBoxManage hostonlyif create
              cat /tmp/VBoxSVC.log >&2
            fi
          '';
        postStop =
          ''
            VBoxManage hostonlyif remove vboxnet0
          '';
      };

    networking.interfaces.vboxnet0.ipv4.addresses = [{ address = "192.168.56.1"; prefixLength = 24; }];
    # Make sure NetworkManager won't assume this interface being up
    # means we have internet access.
    networking.networkmanager.unmanaged = ["vboxnet0"];
  }) (mkIf config.networking.useNetworkd {
    systemd.network.networks."40-vboxnet0".extraConfig = ''
      [Link]
      RequiredForOnline=no
    '';
  })

]);
}
