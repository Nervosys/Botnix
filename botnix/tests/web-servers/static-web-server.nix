import ../make-test-python.nix ({ pkgs, lib, ... } : {
  name = "static-web-server";
  meta = {
    maintainers = with lib.maintainers; [ mac-chaffee ];
  };

  nodes.machine = { pkgs, ... }: {
    services.static-web-server = {
      enable = true;
      listen = "[::]:8080";
      root = toString (pkgs.writeTextDir "botnix-test.html" ''
        <h1>Hello Botnix!</h1>
      '');
      configuration = {
        general = { directory-listing = true; };
      };
    };
  };

  testScript = ''
    machine.start()
    machine.wait_for_unit("static-web-server.socket")
    machine.wait_for_open_port(8080)
    # We don't use wait_until_succeeds() because we're testing socket
    # activation which better work on the first request
    response = machine.succeed("curl -fsS localhost:8080")
    assert "botnix-test.html" in response, "The directory listing page did not include a link to our botnix-test.html file"
    response = machine.succeed("curl -fsS localhost:8080/botnix-test.html")
    assert "Hello Botnix!" in response
    machine.wait_for_unit("static-web-server.service")
  '';
})
