import ./make-test-python.nix ({ pkgs, lib, ... }: {
  name = "containers-ephemeral";
  meta = {
    maintainers = with lib.maintainers; [ patryk27 ];
  };

  nodes.machine = { pkgs, ... }: {
    virtualisation.writableStore = true;

    containers.webserver = {
      ephemeral = true;
      privateNetwork = true;
      hostAddress = "10.231.136.1";
      localAddress = "10.231.136.2";
      config = {
        services.nginx = {
          enable = true;
          virtualHosts.localhost = {
            root = pkgs.runCommand "localhost" {} ''
              mkdir "$out"
              echo hello world > "$out/index.html"
            '';
          };
        };
        networking.firewall.allowedTCPPorts = [ 80 ];
      };
    };
  };

  testScript = ''
    assert "webserver" in machine.succeed("botnix-container list")

    machine.succeed("botnix-container start webserver")

    with subtest("Container got its own root folder"):
        machine.succeed("ls /run/botnix-containers/webserver")

    with subtest("Container persistent directory is not created"):
        machine.fail("ls /var/lib/botnix-containers/webserver")

    # Since "start" returns after the container has reached
    # multi-user.target, we should now be able to access it.
    ip = machine.succeed("botnix-container show-ip webserver").rstrip()
    machine.succeed(f"ping -n -c1 {ip}")
    machine.succeed(f"curl --fail http://{ip}/ > /dev/null")

    with subtest("Stop the container"):
        machine.succeed("botnix-container stop webserver")
        machine.fail(f"curl --fail --connect-timeout 2 http://{ip}/ > /dev/null")

    with subtest("Container's root folder was removed"):
        machine.fail("ls /run/botnix-containers/webserver")
  '';
})
