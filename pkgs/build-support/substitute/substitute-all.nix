{ stdenvNoCC }:

args:

# see the substituteAll in the botpkgs documentation for usage and constaints
stdenvNoCC.mkDerivation ({
  name = if args ? name then args.name else baseNameOf (toString args.src);
  builder = ./substitute-all.sh;
  inherit (args) src;
  preferLocalBuild = true;
  allowSubstitutes = false;
} // args)
