{ lib, stdenv, fetchurl, file, zlib, libgnurx
, testers
}:

# Note: this package is used for bootstrapping fetchurl, and thus
# cannot use fetchpatch! All mutable patches (generated by GitHub or
# cgit) that are needed here should be included directly in Botpkgs as
# files.

stdenv.mkDerivation (finalAttrs: {
  pname = "file";
  version = "5.45";

  src = fetchurl {
    urls = [
      "https://astron.com/pub/file/${finalAttrs.pname}-${finalAttrs.version}.tar.gz"
      "https://distfiles.macports.org/file/${finalAttrs.pname}-${finalAttrs.version}.tar.gz"
    ];
    hash = "sha256-/Jf1ECm7DiyfTjv/79r2ePDgOe6HK53lwAKm0Jx4TYI=";
  };

  outputs = [ "out" "dev" "man" ];

  patches = [
    # Upstream patch to fix 32-bit tests.
    # Will be included in 5.46+ releases.
    ./32-bit-time_t.patch
  ];

  strictDeps = true;
  enableParallelBuilding = true;

  nativeBuildInputs = lib.optional (stdenv.hostPlatform != stdenv.buildPlatform) file;
  buildInputs = [ zlib ]
    ++ lib.optional stdenv.hostPlatform.isWindows libgnurx;

  # https://bugs.astron.com/view.php?id=382
  doCheck = !stdenv.buildPlatform.isMusl;

  makeFlags = lib.optional stdenv.hostPlatform.isWindows "FILE_COMPILE=file";

  passthru.tests.pkg-config = testers.testMetaPkgConfig finalAttrs.finalPackage;

  meta = with lib; {
    homepage = "https://darwinsys.com/file";
    description = "A program that shows the type of files";
    maintainers = with maintainers; [ doronbehar ];
    license = licenses.bsd2;
    pkgConfigModules = [ "libmagic" ];
    platforms = platforms.all;
    mainProgram = "file";
  };
})
