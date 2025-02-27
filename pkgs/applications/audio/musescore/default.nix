{ stdenv
, lib
, fetchFromGitHub
, fetchpatch
, cmake
, wrapQtAppsHook
, pkg-config
, ninja
, alsa-lib
, alsa-plugins
, freetype
, libjack2
, lame
, libogg
, libpulseaudio
, libsndfile
, libvorbis
, portaudio
, portmidi
, qtbase
, qtdeclarative
, qtgraphicaleffects
, flac
, qtquickcontrols
, qtquickcontrols2
, qtscript
, qtsvg
, qtxmlpatterns
, qtnetworkauth
, qtx11extras
, nixosTests
, darwin
}:

let
  stdenv' = if stdenv.isDarwin then darwin.apple_sdk_11_0.stdenv else stdenv;
  # portaudio propagates Darwin frameworks. Rebuild it using the 11.0 stdenv
  # from Qt and the 11.0 SDK frameworks.
  portaudio' = if stdenv.isDarwin then portaudio.override {
    stdenv = stdenv';
    inherit (darwin.apple_sdk_11_0.frameworks)
      AudioUnit
      AudioToolbox
      CoreAudio
      CoreServices
      Carbon
    ;
  } else portaudio;
in stdenv'.mkDerivation (finalAttrs: {
  pname = "musescore";
  version = "4.2.1";

  src = fetchFromGitHub {
    owner = "musescore";
    repo = "MuseScore";
    rev = "v${finalAttrs.version}";
    sha256 = "sha256-YCeO/ijxA+tZxNviqmlIBkAdjPTrKoOoo1QyMIOqhWU=";
  };

  cmakeFlags = [
    "-DMUSESCORE_BUILD_MODE=release"
    # Disable the build and usage of the `/bin/crashpad_handler` utility - it's
    # not useful on Botnix, see:
    # https://github.com/musescore/MuseScore/issues/15571
    "-DMUE_BUILD_CRASHPAD_CLIENT=OFF"
    # Use our freetype
    "-DMUE_COMPILE_USE_SYSTEM_FREETYPE=ON"
    # From some reason, in $src/build/cmake/SetupBuildEnvironment.cmake,
    # upstream defaults to compiling to x86_64 only, unless this cmake flag is
    # set
    "-DMUE_COMPILE_BUILD_MACOS_APPLE_SILICON=ON"
    # Don't bundle qt qml files, relevant really only for darwin, but we set
    # this for all platforms anyway.
    "-DMUE_COMPILE_INSTALL_QTQML_FILES=OFF"
  ];

  qtWrapperArgs = [
    # MuseScore JACK backend loads libjack at runtime.
    "--prefix ${lib.optionalString stdenv.isDarwin "DY"}LD_LIBRARY_PATH : ${lib.makeLibraryPath [ libjack2 ]}"
  ] ++ lib.optionals (stdenv.isLinux) [
    "--set ALSA_PLUGIN_DIR ${alsa-plugins}/lib/alsa-lib"
  ] ++ lib.optionals (!stdenv.isDarwin) [
    # There are some issues with using the wayland backend, see:
    # https://musescore.org/en/node/321936
    "--set-default QT_QPA_PLATFORM xcb"
  ];

  # HACK `propagatedSandboxProfile` does not appear to actually propagate the
  # sandbox profile from `qtbase`, see:
  # https://github.com/nervosys/Botnix/issues/237458
  sandboxProfile = toString qtbase.__propagatedSandboxProfile or null;

  nativeBuildInputs = [
    wrapQtAppsHook
    cmake
    pkg-config
    ninja
  ];

  buildInputs = [
    libjack2
    freetype
    lame
    libogg
    libpulseaudio
    libsndfile
    libvorbis
    portaudio'
    portmidi
    flac
    qtbase
    qtdeclarative
    qtgraphicaleffects
    qtquickcontrols
    qtquickcontrols2
    qtscript
    qtsvg
    qtxmlpatterns
    qtnetworkauth
    qtx11extras
  ] ++ lib.optionals stdenv.isLinux [
    alsa-lib
  ];

  postInstall = ''
    # Remove unneeded bundled libraries and headers
    rm -r $out/{include,lib}
  '' + lib.optionalString stdenv.isDarwin ''
    mkdir -p "$out/Applications"
    mv "$out/mscore.app" "$out/Applications/mscore.app"
    mkdir -p $out/bin
    ln -s $out/Applications/mscore.app/Contents/MacOS/mscore $out/bin/mscore.
  '';

  # Don't run bundled upstreams tests, as they require a running X window system.
  doCheck = false;

  passthru.tests = nixosTests.musescore;

  meta = with lib; {
    description = "Music notation and composition software";
    homepage = "https://musescore.org/";
    license = licenses.gpl3Only;
    maintainers = with maintainers; [ vandenoever doronbehar ];
    # on aarch64-linux:
    # error: cannot convert '<brace-enclosed initializer list>' to 'float32x4_t' in assignment
    broken = (stdenv.isLinux && stdenv.isAarch64);
    mainProgram = "mscore";
  };
})
