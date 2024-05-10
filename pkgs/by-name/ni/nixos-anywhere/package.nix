{ stdenv
, fetchFromGitHub
, openssh
, gitMinimal
, rsync
, nix
, coreutils
, curl
, gnugrep
, gawk
, findutils
, gnused
, lib
, makeWrapper
}:
let
  runtimeDeps = [
    gitMinimal # for git flakes
    rsync
    nix
    coreutils
    curl # when uploading tarballs
    gnugrep
    gawk
    findutils
    gnused # needed by ssh-copy-id
  ];
in
stdenv.mkDerivation (finalAttrs: {
  pname = "botnix-anywhere";
  version = "1.1.1";
  src = fetchFromGitHub {
    owner = "numtide";
    repo = "botnix-anywhere";
    rev = finalAttrs.version;
    hash = "sha256-GN0G3g3QEzb2ZG3zSzbRaRBsmQsWJu81CZy9mIofRZ0=";
  };
  nativeBuildInputs = [ makeWrapper ];
  installPhase = ''
    install -D -m 0755 src/botnix-anywhere.sh $out/bin/botnix-anywhere

    # We prefer the system's openssh over our own, since it might come with features not present in ours:
    # https://github.com/numtide/botnix-anywhere/issues/62
    wrapProgram $out/bin/botnix-anywhere \
      --prefix PATH : ${lib.makeBinPath runtimeDeps} --suffix PATH : ${lib.makeBinPath [ openssh ]}
  '';

  meta = with lib; {
    description = "Install botnix everywhere via ssh";
    homepage = "https://github.com/numtide/botnix-anywhere";
    mainProgram = "botnix-anywhere";
    license = licenses.mit;
    platforms = platforms.all;
    maintainers = [ maintainers.mic92 maintainers.lassulus maintainers.phaer ];
  };
})
