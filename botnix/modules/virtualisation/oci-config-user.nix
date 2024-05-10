{ modulesPath, ... }:

{
  # To build the configuration or use nix-env, you need to run
  # either botnix-rebuild --upgrade or nix-channel --update
  # to fetch the botnix channel.

  # This configures everything but bootstrap services,
  # which only need to be run once and have already finished
  # if you are able to see this comment.
  imports = [ "${modulesPath}/virtualisation/oci-common.nix" ];
}
