# Botnix test for usbrelayd
#
# It is not stored in botnix/tests directory, because it requires the
# USB relay connected to the host computer and as such, it cannot be
# run automatically.
#
# Run this test as:
#
#     nix-build test.nix -A driverInteractive && ./result/bin/botnix-test-driver --no-interactive
#
# The interactive driver is required because the default
# (non-interactive) driver uses qemu without support for passing USB
# devices to the guest (see
# https://discourse.nixos.org/t/hardware-dependent-botnix-tests/18564
# for discussion of other alternatives).

import ../../../../botnix/tests/make-test-python.nix ({ pkgs, ... }: {
  name = "usbrelayd";

  nodes.machine = {
    virtualisation.qemu.options = [
      "-device qemu-xhci"
      "-device usb-host,vendorid=0x16c0,productid=0x05df"
    ];
    services.usbrelayd.enable = true;
    systemd.services.usbrelayd = {
      after = [ "mosquitto.service" ];
    };
    services.mosquitto = {
      enable = true;
      listeners = [{
        acl = [ "pattern readwrite #" ];
        omitPasswordAuth = true;
        settings.allow_anonymous = true;
      }];
    };
    environment.systemPackages = [
      pkgs.usbrelay
      pkgs.mosquitto
    ];
    documentation.botnix.enable = false; # building botnix manual takes long time
  };

  testScript = ''
    import os
    if os.waitstatus_to_exitcode(os.system("lsusb -d 16c0:05df")) != 0:
        print("No USB relay detected, skipping test")
        import sys
        sys.exit(2)
    machine.start()
    # usbrelayd is started by udev when an relay is detected
    machine.wait_for_unit("usbrelayd.service")

    stdout = machine.succeed("usbrelay")
    relay_id = stdout.split(sep="_")[0]
    assert relay_id != ""
    import time
    time.sleep(1)
    machine.succeed(f"mosquitto_pub -h localhost -t cmnd/{relay_id}/1 -m ON")
    time.sleep(1)
    machine.succeed(f"mosquitto_pub -h localhost -t cmnd/{relay_id}/1 -m OFF")
    print("Did you see the relay switching on and off?")
  '';
})
