{ someDrv }: someDrv // {
  escapeAbsolute = /bar;
  escapeRelative = ../.;
  nixPath = <botpkgs>;
  pathWithSubexpr = ./${"test"};
}
