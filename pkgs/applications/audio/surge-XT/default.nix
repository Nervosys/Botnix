{ stdenv
, lib
, fetchFromGitHub
, cmake
, pkg-config
, alsa-lib
, freetype
, libjack2
, lv2
, libX11
, libXcursor
, libXext
, libXinerama
, libXrandr
}:

let
  juce-lv2 = stdenv.mkDerivation {
    pname = "juce-lv2";
    version = "unstable-2023-03-04";

    # lv2 branch
    src = fetchFromGitHub {
      owner = "lv2-porting-project";
      repo = "JUCE";
      rev = "e825ad977cf4499a7bfa05b97b208236f8fd253b";
      sha256 = "sha256-Fqp1y9BN0E9p/12ukG1oh3COhXNRWBAlFRSl0LPyiFc=";
    };

    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      cp -r . $out
    '';
  };
in
stdenv.mkDerivation rec {
  pname = "surge-XT";
  version = "1.2.3";

  src = fetchFromGitHub {
    owner = "surge-synthesizer";
    repo = "surge";
    rev = "release_xt_${version}";
    fetchSubmodules = true;
    sha256 = "sha256-DGzdzoCjMGEDltEwlPvLk2tyMVRH1Ql2Iq1ypogw/m0=";
  };

  nativeBuildInputs = [
    cmake
    pkg-config
  ];

  buildInputs = [
    alsa-lib
    freetype
    libjack2
    lv2
    libX11
    libXcursor
    libXext
    libXinerama
    libXrandr
  ];

  enableParallelBuilding = true;

  cmakeFlags = [
    "-DJUCE_SUPPORTS_LV2=ON"
    "-DSURGE_JUCE_PATH=${juce-lv2}"
  ];

  CXXFLAGS = [
    # GCC 13: error: 'uint32_t' has not been declared
    "-include cstdint"
  ];

  # JUCE dlopen's these at runtime, crashes without them
  NIX_LDFLAGS = (toString [
    "-lX11"
    "-lXext"
    "-lXcursor"
    "-lXinerama"
    "-lXrandr"
  ]);

  # see https://github.com/nervosys/Botnix/pull/149487#issuecomment-991747333
  postPatch = ''
    export XDG_DOCUMENTS_DIR=$(mktemp -d)
  '';

  meta = with lib; {
    description = "LV2 & VST3 synthesizer plug-in (previously released as Vember Audio Surge)";
    homepage = "https://surge-synthesizer.github.io";
    license = licenses.gpl3;
    platforms = [ "x86_64-linux" ];
    maintainers = with maintainers; [ magnetophon orivej ];
  };
}
