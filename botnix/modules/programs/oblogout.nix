{ config, lib, pkgs, ... }:

with lib;

{

  imports = [
    (mkRemovedOptionModule [ "programs" "oblogout" ] "programs.oblogout has been removed from Botnix. This is because the oblogout repository has been archived upstream.")
  ];

}
