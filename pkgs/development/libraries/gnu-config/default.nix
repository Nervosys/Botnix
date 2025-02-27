{ lib, stdenv, fetchurl }:

# Note: this package is used for bootstrapping fetchurl, and thus
# cannot use fetchpatch! All mutable patches (generated by GitHub or
# cgit) that are needed here should be included directly in Botpkgs as
# files.

let
  rev = "28ea239c53a2d5d8800c472bc2452eaa16e37af2";

  # Don't use fetchgit as this is needed during Aarch64 bootstrapping
  configGuess = fetchurl {
    name = "config.guess-${builtins.substring 0 7 rev}";
    url = "https://git.savannah.gnu.org/cgit/config.git/plain/config.guess?id=${rev}";
    hash = "sha256-7CV3YUJSMm+InfHel7mkV8A6mpSBEEhWPCEaRElti6M=";
  };
  configSub = fetchurl {
    name = "config.sub-${builtins.substring 0 7 rev}";
    url = "https://git.savannah.gnu.org/cgit/config.git/plain/config.sub?id=${rev}";
    hash = "sha256-Rlxf5nx9NrcugIgScWRF1NONS5RzTKjTaoY50SMjh4s=";
  };
in stdenv.mkDerivation {
  pname = "gnu-config";
  version = "2023-09-19";

  unpackPhase = ''
    runHook preUnpack
    cp ${configGuess} ./config.guess
    cp ${configSub} ./config.sub
    chmod +w ./config.sub ./config.guess
    runHook postUnpack
  '';

  # If this isn't set, `pkgs.gnu-config.overrideAttrs( _: { patches
  # = ...; })` will behave very counterintuitively: the (unpatched)
  # gnu-config from the updateAutotoolsGnuConfigScriptsHook stdenv's
  # defaultNativeBuildInputs will "update" the patched gnu-config by
  # reverting the patch!
  dontUpdateAutotoolsGnuConfigScripts = true;

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 ./config.guess $out/config.guess
    install -Dm755 ./config.sub $out/config.sub
    runHook postInstall
  '';

  meta = with lib; {
    description = "Attempt to guess a canonical system name";
    homepage = "https://savannah.gnu.org/projects/config";
    license = licenses.gpl3;
    # In addition to GPLv3:
    #   As a special exception to the GNU General Public License, if you
    #   distribute this file as part of a program that contains a
    #   configuration script generated by Autoconf, you may include it under
    #   the same distribution terms that you use for the rest of that
    #   program.
    maintainers = with maintainers; [ dezgeg emilytrau ];
    platforms = platforms.all;
  };
}
