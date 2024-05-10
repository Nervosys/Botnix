{ writeShellApplication, iptables, lib }:

writeShellApplication {
  name = "botnix-firewall-tool";
  text = builtins.readFile ./botnix-firewall-tool.sh;
  runtimeInputs = [
    iptables
  ];

  meta = with lib; {
    description = "Temporarily manipulate the Botnix firewall";
    license = licenses.mit;
    maintainers = with maintainers; [ clerie ];
  };
}
