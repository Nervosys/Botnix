# Env to update Gemfile.lock / gemset.nix

with import <botpkgs> {};
stdenv.mkDerivation {
  name = "env";
  buildInputs = [
    ruby.devEnv
    gnumake
    bundix
  ];
}
