# nix run ../../../../..#cabal2nix -- ./.
{ mkDerivation, base, lib }:
mkDerivation {
  pname = "local";
  version = "0.1.0.0";
  src = ./.;
  isLibrary = false;
  isExecutable = true;
  executableHaskellDepends = [ base ];
  description = "Botpkgs test case";
  license = lib.licenses.mit;
}
