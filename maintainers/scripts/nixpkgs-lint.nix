{ stdenv, lib, makeWrapper, perl, perlPackages }:

stdenv.mkDerivation {
  name = "botpkgs-lint-1";

  nativeBuildInputs = [ makeWrapper ];
  buildInputs = [ perl perlPackages.XMLSimple ];

  dontUnpack = true;
  buildPhase = "true";

  installPhase =
    ''
      mkdir -p $out/bin
      cp ${./botpkgs-lint.pl} $out/bin/botpkgs-lint
      wrapProgram $out/bin/botpkgs-lint --set PERL5LIB $PERL5LIB
    '';

  meta = with lib; {
    maintainers = [ maintainers.eelco ];
    description = "A utility for Botpkgs contributors to check Botpkgs for common errors";
    platforms = platforms.unix;
  };
}
