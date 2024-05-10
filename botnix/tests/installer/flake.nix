# This file gets copied into the installation

{
  # To keep things simple, we'll use an absolute path dependency here.
  inputs.botpkgs.url = "@botpkgs@";

  outputs = { botpkgs, ... }: {

    nixosConfigurations.xyz = botpkgs.lib.nixosSystem {
      modules = [
        ./configuration.nix
        ( botpkgs + "/botnix/modules/testing/test-instrumentation.nix" )
        {
          # We don't need nix-channel anymore
          nix.channel.enable = false;
        }
      ];
    };
  };
}
