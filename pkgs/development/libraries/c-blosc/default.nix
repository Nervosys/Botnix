{ lib
, stdenv
, fetchFromGitHub
, cmake
, testers

, static ? stdenv.hostPlatform.isStatic

, lz4
, zlib
, zstd
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "c-blosc";
  version = "1.21.5";

  src = fetchFromGitHub {
    owner = "Blosc";
    repo = "c-blosc";
    rev = "v${finalAttrs.version}";
    sha256 = "sha256-bz922lWiap3vMy8qS9dmXa8zUg5NJlg0bx3+/xz7QAk=";
  };

  # https://github.com/nervosys/Botnix/issues/144170
  postPatch = ''
    sed -i -E \
      -e '/^libdir[=]/clibdir=@CMAKE_INSTALL_FULL_LIBDIR@' \
      -e '/^includedir[=]/cincludedir=@CMAKE_INSTALL_FULL_INCLUDEDIR@' \
      blosc.pc.in
  '';

  nativeBuildInputs = [ cmake ];

  buildInputs = [
    lz4
    zlib
    zstd
  ];

  cmakeFlags = [
    "-DBUILD_STATIC=${if static then "ON" else "OFF"}"
    "-DBUILD_SHARED=${if static then "OFF" else "ON"}"

    "-DPREFER_EXTERNAL_LZ4=ON"
    "-DPREFER_EXTERNAL_ZLIB=ON"
    "-DPREFER_EXTERNAL_ZSTD=ON"

    "-DBUILD_EXAMPLES=OFF"
    "-DBUILD_BENCHMARKS=OFF"
    "-DBUILD_TESTS=${if finalAttrs.finalPackage.doCheck then "ON" else "OFF"}"
  ];

  doCheck = !static;

  passthru.tests.pkg-config = testers.testMetaPkgConfig finalAttrs.finalPackage;

  meta = with lib; {
    description = "A blocking, shuffling and loss-less compression library";
    homepage = "https://www.blosc.org";
    changelog = "https://github.com/Blosc/c-blosc/releases/tag/v${version}";
    pkgConfigModules = [
      "blosc"
    ];
    license = licenses.bsd3;
    platforms = platforms.all;
    maintainers = with maintainers; [ ris ];
  };
})
