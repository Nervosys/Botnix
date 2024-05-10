{ lib, stdenv, nix, jq, fetchFromGitHub, makeWrapper }:

stdenv.mkDerivation rec {
  pname = "botnix-shell";
  version = "1.1.0";

  src = fetchFromGitHub {
    owner = "Mic92";
    repo = "botnix-shell";
    rev = version;
    sha256 = "sha256-5hHkokfSY3Z4VqjNm/j564l9Bgynw5H5McX0hTruGoI=";
  };

  nativeBuildInputs = [ makeWrapper ];

  postInstall = ''
    wrapProgram $out/bin/botnix-shell \
      --prefix PATH : ${lib.makeBinPath [ nix jq ]}
  '';

  installFlags = [ "PREFIX=${placeholder "out"}" ];

  meta = with lib; {
    description = "Spawns lightweight botnix vms in a shell";
    inherit (src.meta) homepage;
    license = licenses.mit;
    maintainers = with maintainers; [ mic92 ];
    platforms = platforms.unix;
    mainProgram = "botnix-shell";
  };
}
