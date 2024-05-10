{ lib
, stdenv
, boost
, cmake
, pkg-config
, installShellFiles
, nix
}:

stdenv.mkDerivation {
  name = "botnix-option";

  src = ./.;
  postInstall = ''
    installManPage ${./botnix-option.8}
  '';

  strictDeps = true;
  nativeBuildInputs = [
    cmake
    pkg-config
    installShellFiles
  ];
  buildInputs = [
    boost
    nix
  ];
  cmakeFlags = [
    "-DNIX_DEV_INCLUDEPATH=${nix.dev}/include/nix"
  ];

  meta = with lib; {
    license = licenses.lgpl2Plus;
    mainProgram = "botnix-option";
    maintainers = with maintainers; [ ];
    inherit (nix.meta) platforms;
  };
}
