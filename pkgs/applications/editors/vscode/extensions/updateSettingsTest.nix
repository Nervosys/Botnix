with import <botpkgs>{};
callPackage (import ./updateSettings.nix) {} {
  settings = {
    a = "fdsdf";
  };
}
