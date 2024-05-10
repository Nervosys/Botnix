{ stdenv, fetchFromGitHub, lib }:

stdenv.mkDerivation rec {
  pname = "calamares-botnix-extensions";
  version = "0.3.14";

  src = fetchFromGitHub {
    owner = "Botnix";
    repo = "calamares-botnix-extensions";
    rev = version;
    hash = "sha256-wRKZ80yU3WsUkGn5/ft4wDR22s39/WTxTrjFE0/9mlc=";
  };

  installPhase = ''
    runHook preInstall
    mkdir -p $out/{lib,share}/calamares
    cp -r modules $out/lib/calamares/
    cp -r config/* $out/share/calamares/
    cp -r branding $out/share/calamares/
    runHook postInstall
  '';

  meta = with lib; {
    description = "Calamares modules for Botnix";
    homepage = "https://github.com/Botnix/calamares-botnix-extensions";
    license = with licenses; [ gpl3Plus bsd2 cc-by-40 cc-by-sa-40 cc0 ];
    maintainers = with maintainers; [ vlinkz ];
    platforms = platforms.linux;
  };
}
