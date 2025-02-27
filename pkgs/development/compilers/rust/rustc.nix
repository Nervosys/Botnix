{ lib, stdenv, removeReferencesTo, pkgsBuildBuild, pkgsBuildHost, pkgsBuildTarget, targetPackages
, llvmShared, llvmSharedForBuild, llvmSharedForHost, llvmSharedForTarget, llvmPackages
, fetchurl, file, python3
, darwin, cargo, cmake, rustc, rustfmt
, pkg-config, openssl, xz
, libiconv
, which, libffi
, withBundledLLVM ? false
, enableRustcDev ? true
, version
, sha256
, patches ? []
, fd
, ripgrep
, wezterm
, firefox
, thunderbird
# This only builds std for target and reuses the rustc from build.
, fastCross
, lndir
, makeWrapper
}:

let
  inherit (lib) optionals optional optionalString concatStringsSep;
  inherit (darwin.apple_sdk.frameworks) Security;
in stdenv.mkDerivation (finalAttrs: {
  pname = "${targetPackages.stdenv.cc.targetPrefix}rustc";
  inherit version;

  src = fetchurl {
    url = "https://static.rust-lang.org/dist/rustc-${version}-src.tar.gz";
    inherit sha256;
    # See https://nixos.org/manual/botpkgs/stable/#using-git-bisect-on-the-rust-compiler
    passthru.isReleaseTarball = true;
  };

  __darwinAllowLocalNetworking = true;

  # rustc complains about modified source files otherwise
  dontUpdateAutotoolsGnuConfigScripts = true;

  # Running the default `strip -S` command on Darwin corrupts the
  # .rlib files in "lib/".
  #
  # See https://github.com/nervosys/Botnix/pull/34227
  #
  # Running `strip -S` when cross compiling can harm the cross rlibs.
  # See: https://github.com/nervosys/Botnix/pull/56540#issuecomment-471624656
  stripDebugList = [ "bin" ];

  # The Rust pkg-config crate does not support prefixed pkg-config executables[1],
  # but it does support checking these idiosyncratic PKG_CONFIG_${TRIPLE}
  # environment variables.
  # [1]: https://github.com/rust-lang/pkg-config-rs/issues/53
  "PKG_CONFIG_${builtins.replaceStrings ["-"] ["_"] stdenv.buildPlatform.rust.rustcTarget}" =
    "${pkgsBuildHost.stdenv.cc.targetPrefix}pkg-config";

  NIX_LDFLAGS = toString (
       # when linking stage1 libstd: cc: undefined reference to `__cxa_begin_catch'
       optional (stdenv.isLinux && !withBundledLLVM) "--push-state --as-needed -lstdc++ --pop-state"
    ++ optional (stdenv.isDarwin && !withBundledLLVM) "-lc++ -lc++abi"
    ++ optional stdenv.isDarwin "-rpath ${llvmSharedForHost}/lib");

  # Increase codegen units to introduce parallelism within the compiler.
  RUSTFLAGS = "-Ccodegen-units=10";

  RUSTDOCFLAGS = "-A rustdoc::broken-intra-doc-links";

  # We need rust to build rust. If we don't provide it, configure will try to download it.
  # Reference: https://github.com/rust-lang/rust/blob/master/src/bootstrap/configure.py
  configureFlags = let
    prefixForStdenv = stdenv: "${stdenv.cc}/bin/${stdenv.cc.targetPrefix}";
    ccPrefixForStdenv = stdenv: "${prefixForStdenv stdenv}${if (stdenv.cc.isClang or false) then "clang" else "cc"}";
    cxxPrefixForStdenv = stdenv: "${prefixForStdenv stdenv}${if (stdenv.cc.isClang or false) then "clang++" else "c++"}";
    setBuild  = "--set=target.${stdenv.buildPlatform.rust.rustcTarget}";
    setHost   = "--set=target.${stdenv.hostPlatform.rust.rustcTarget}";
    setTarget = "--set=target.${stdenv.targetPlatform.rust.rustcTarget}";
    ccForBuild  = ccPrefixForStdenv pkgsBuildBuild.targetPackages.stdenv;
    cxxForBuild  = cxxPrefixForStdenv pkgsBuildBuild.targetPackages.stdenv;
    ccForHost  = ccPrefixForStdenv pkgsBuildHost.targetPackages.stdenv;
    cxxForHost  = cxxPrefixForStdenv pkgsBuildHost.targetPackages.stdenv;
    ccForTarget  = ccPrefixForStdenv pkgsBuildTarget.targetPackages.stdenv;
    cxxForTarget  = cxxPrefixForStdenv pkgsBuildTarget.targetPackages.stdenv;
  in [
    "--sysconfdir=${placeholder "out"}/etc"
    "--release-channel=stable"
    "--set=build.rustc=${rustc}/bin/rustc"
    "--set=build.cargo=${cargo}/bin/cargo"
  ] ++ lib.optionals (!(finalAttrs.src.passthru.isReleaseTarball or false)) [
    # release tarballs vendor the rustfmt source; when
    # git-bisect'ing from upstream's git repo we must prevent
    # attempts to download the missing source tarball
    "--set=build.rustfmt=${rustfmt}/bin/rustfmt"
  ] ++ [
    "--tools=rustc,rust-analyzer-proc-macro-srv"
    "--enable-rpath"
    "--enable-vendor"
    "--build=${stdenv.buildPlatform.rust.rustcTargetSpec}"
    "--host=${stdenv.hostPlatform.rust.rustcTargetSpec}"
    # std is built for all platforms in --target.
    "--target=${concatStringsSep "," ([
      stdenv.targetPlatform.rust.rustcTargetSpec

    # Other targets that don't need any extra dependencies to build.
    ] ++ optionals (!fastCross) [
      "wasm32-unknown-unknown"

    # (build!=target): When cross-building a compiler we need to add
    # the build platform as well so rustc can compile build.rs
    # scripts.
    ] ++ optionals (stdenv.buildPlatform != stdenv.targetPlatform && !fastCross) [
      stdenv.buildPlatform.rust.rustcTargetSpec

    # (host!=target): When building a cross-targeting compiler we
    # need to add the host platform as well so rustc can compile
    # build.rs scripts.
    ] ++ optionals (stdenv.hostPlatform != stdenv.targetPlatform && !fastCross) [
      stdenv.hostPlatform.rust.rustcTargetSpec
    ])}"

    "${setBuild}.cc=${ccForBuild}"
    "${setHost}.cc=${ccForHost}"
    "${setTarget}.cc=${ccForTarget}"

    "${setBuild}.linker=${ccForBuild}"
    "${setHost}.linker=${ccForHost}"
    "${setTarget}.linker=${ccForTarget}"

    "${setBuild}.cxx=${cxxForBuild}"
    "${setHost}.cxx=${cxxForHost}"
    "${setTarget}.cxx=${cxxForTarget}"

    "${setBuild}.crt-static=${lib.boolToString stdenv.buildPlatform.isStatic}"
    "${setHost}.crt-static=${lib.boolToString stdenv.hostPlatform.isStatic}"
    "${setTarget}.crt-static=${lib.boolToString stdenv.targetPlatform.isStatic}"
  ] ++ optionals (!withBundledLLVM) [
    "--enable-llvm-link-shared"
    "${setBuild}.llvm-config=${llvmSharedForBuild.dev}/bin/llvm-config"
    "${setHost}.llvm-config=${llvmSharedForHost.dev}/bin/llvm-config"
    "${setTarget}.llvm-config=${llvmSharedForTarget.dev}/bin/llvm-config"
  ] ++ optionals (stdenv.isLinux && !stdenv.targetPlatform.isRedox) [
    "--enable-profiler" # build libprofiler_builtins
  ] ++ optionals stdenv.buildPlatform.isMusl [
    "${setBuild}.musl-root=${pkgsBuildBuild.targetPackages.stdenv.cc.libc}"
  ] ++ optionals stdenv.hostPlatform.isMusl [
    "${setHost}.musl-root=${pkgsBuildHost.targetPackages.stdenv.cc.libc}"
  ] ++ optionals stdenv.targetPlatform.isMusl [
    "${setTarget}.musl-root=${pkgsBuildTarget.targetPackages.stdenv.cc.libc}"
  ] ++ optionals stdenv.targetPlatform.rust.isNoStdTarget [
    "--disable-docs"
  ] ++ optionals (stdenv.isDarwin && stdenv.isx86_64) [
    # https://github.com/rust-lang/rust/issues/92173
    "--set rust.jemalloc"
  ];

  # if we already have a rust compiler for build just compile the target std
  # library and reuse compiler
  buildPhase = if fastCross then "
    runHook preBuild

    mkdir -p build/${stdenv.hostPlatform.rust.rustcTargetSpec}/stage0-{std,rustc}/${stdenv.hostPlatform.rust.rustcTargetSpec}/release/
    ln -s ${rustc.unwrapped}/lib/rustlib/${stdenv.hostPlatform.rust.rustcTargetSpec}/libstd-*.so build/${stdenv.hostPlatform.rust.rustcTargetSpec}/stage0-std/${stdenv.hostPlatform.rust.rustcTargetSpec}/release/libstd.so
    ln -s ${rustc.unwrapped}/lib/rustlib/${stdenv.hostPlatform.rust.rustcTargetSpec}/librustc_driver-*.so build/${stdenv.hostPlatform.rust.rustcTargetSpec}/stage0-rustc/${stdenv.hostPlatform.rust.rustcTargetSpec}/release/librustc.so
    ln -s ${rustc.unwrapped}/bin/rustc build/${stdenv.hostPlatform.rust.rustcTargetSpec}/stage0-rustc/${stdenv.hostPlatform.rust.rustcTargetSpec}/release/rustc-main
    touch build/${stdenv.hostPlatform.rust.rustcTargetSpec}/stage0-std/${stdenv.hostPlatform.rust.rustcTargetSpec}/release/.libstd.stamp
    touch build/${stdenv.hostPlatform.rust.rustcTargetSpec}/stage0-rustc/${stdenv.hostPlatform.rust.rustcTargetSpec}/release/.librustc.stamp
    python ./x.py --keep-stage=0 --stage=1 build library

    runHook postBuild
  " else null;

  installPhase = if fastCross then ''
    runHook preInstall

    python ./x.py --keep-stage=0 --stage=1 install library/std
    mkdir -v $out/bin $doc $man
    ln -s ${rustc.unwrapped}/bin/rustc $out/bin
    makeWrapper ${rustc.unwrapped}/bin/rustdoc $out/bin/rustdoc --add-flags "--sysroot $out"
    ln -s ${rustc.unwrapped}/lib/rustlib/{manifest-rust-std-,}${stdenv.hostPlatform.rust.rustcTargetSpec} $out/lib/rustlib/
    echo rust-std-${stdenv.hostPlatform.rust.rustcTargetSpec} >> $out/lib/rustlib/components
    lndir ${rustc.doc} $doc
    lndir ${rustc.man} $man

    runHook postInstall
  '' else null;

  # the rust build system complains that nix alters the checksums
  dontFixLibtool = true;

  inherit patches;

  postPatch = ''
    patchShebangs src/etc

    ${optionalString (!withBundledLLVM) "rm -rf src/llvm"}

    # Useful debugging parameter
    # export VERBOSE=1
  '' + lib.optionalString (stdenv.targetPlatform.isMusl && !stdenv.targetPlatform.isStatic) ''
    # Upstream rustc still assumes that musl = static[1].  The fix for
    # this is to disable crt-static by default for non-static musl
    # targets.
    #
    # Even though Cargo will build build.rs files for the build platform,
    # cross-compiling _from_ musl appears to work fine, so we only need
    # to do this when rustc's target platform is dynamically linked musl.
    #
    # [1]: https://github.com/rust-lang/compiler-team/issues/422
    substituteInPlace compiler/rustc_target/src/spec/base/linux_musl.rs \
        --replace "base.crt_static_default = true" "base.crt_static_default = false"
  '' + lib.optionalString (stdenv.isDarwin && stdenv.isx86_64) ''
    # See https://github.com/jemalloc/jemalloc/issues/1997
    # Using a value of 48 should work on both emulated and native x86_64-darwin.
    export JEMALLOC_SYS_WITH_LG_VADDR=48
  '' + lib.optionalString (!(finalAttrs.src.passthru.isReleaseTarball or false)) ''
    mkdir .cargo
    cat > .cargo/config <<\EOF
    [source.crates-io]
    replace-with = "vendored-sources"
    [source.vendored-sources]
    directory = "vendor"
    EOF
  '';

  # rustc unfortunately needs cmake to compile llvm-rt but doesn't
  # use it for the normal build. This disables cmake in Nix.
  dontUseCmakeConfigure = true;

  depsBuildBuild = [ pkgsBuildHost.stdenv.cc pkg-config ];

  nativeBuildInputs = [
    file python3 rustc cmake
    which libffi removeReferencesTo pkg-config xz
  ]
    ++ optionals fastCross [ lndir makeWrapper ];

  buildInputs = [ openssl ]
    ++ optionals stdenv.isDarwin [ libiconv Security ]
    ++ optional (!withBundledLLVM) llvmShared;

  outputs = [ "out" "man" "doc" ];
  setOutputFlags = false;

  postInstall = lib.optionalString (enableRustcDev && !fastCross) ''
    # install rustc-dev components. Necessary to build rls, clippy...
    python x.py dist rustc-dev
    tar xf build/dist/rustc-dev*tar.gz
    cp -r rustc-dev*/rustc-dev*/lib/* $out/lib/
    rm $out/lib/rustlib/install.log
    for m in $out/lib/rustlib/manifest-rust*
    do
      sort --output=$m < $m
    done

  '' + ''
    # remove references to llvm-config in lib/rustlib/x86_64-unknown-linux-gnu/codegen-backends/librustc_codegen_llvm-llvm.so
    # and thus a transitive dependency on ncurses
    find $out/lib -name "*.so" -type f -exec remove-references-to -t ${llvmShared} '{}' '+'

    # remove uninstall script that doesn't really make sense for Nix.
    rm $out/lib/rustlib/uninstall.sh
  '';

  configurePlatforms = [];

  enableParallelBuilding = true;

  setupHooks = ./setup-hook.sh;

  requiredSystemFeatures = [ "big-parallel" ];

  passthru = {
    llvm = llvmShared;
    inherit llvmPackages;
    tests = {
      inherit fd ripgrep wezterm;
    } // lib.optionalAttrs stdenv.hostPlatform.isLinux { inherit firefox thunderbird; };
  };

  meta = with lib; {
    homepage = "https://www.rust-lang.org/";
    description = "A safe, concurrent, practical language";
    maintainers = with maintainers; [ havvy ] ++ teams.rust.members;
    license = [ licenses.mit licenses.asl20 ];
    platforms = [
      # Platforms with host tools from
      # https://doc.rust-lang.org/nightly/rustc/platform-support.html
      "x86_64-darwin" "i686-darwin" "aarch64-darwin"
      "i686-freebsd13" "x86_64-freebsd13"
      "x86_64-solaris"
      "aarch64-linux" "armv6l-linux" "armv7l-linux" "i686-linux"
      "loongarch64-linux" "powerpc64-linux" "powerpc64le-linux"
      "riscv64-linux" "s390x-linux" "x86_64-linux"
      "aarch64-netbsd" "armv7l-netbsd" "i686-netbsd" "powerpc-netbsd"
      "x86_64-netbsd"
      "i686-openbsd" "x86_64-openbsd"
      "i686-windows" "x86_64-windows"
    ];
  };
})
