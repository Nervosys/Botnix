{ pkgs ? import ../../.. {} }:

let
  libc = pkgs.stdenv.cc.libc;
  patchelf = pkgs.patchelf.overrideAttrs(previousAttrs: {
    NIX_CFLAGS_COMPILE = (previousAttrs.NIX_CFLAGS_COMPILE or []) ++ [ "-static-libgcc" "-static-libstdc++" ];
    NIX_CFLAGS_LINK = (previousAttrs.NIX_CFLAGS_LINK or []) ++ [ "-static-libgcc" "-static-libstdc++" ];
  });
in with pkgs; rec {


  coreutilsMinimal = coreutils.override (args: {
    # We want coreutils without ACL/attr support.
    aclSupport = false;
    attrSupport = false;
    # Our tooling currently can't handle scripts in bin/, only ELFs and symlinks.
    singleBinary = "symlinks";
  });

  tarMinimal = gnutar.override { acl = null; };

  busyboxMinimal = busybox.override {
    useMusl = lib.meta.availableOn stdenv.hostPlatform musl;
    enableStatic = true;
    enableMinimal = true;
    extraConfig = ''
      CONFIG_ASH y
      CONFIG_ASH_ECHO y
      CONFIG_ASH_TEST y
      CONFIG_ASH_OPTIMIZE_FOR_SIZE y
      CONFIG_MKDIR y
      CONFIG_TAR y
      CONFIG_UNXZ y
    '';
  };

  bootGCC = gcc.cc.override { enableLTO = false; };
  bootBinutils = binutils.bintools.override {
    withAllTargets = false;
    # Don't need two linkers, disable whatever's not primary/default.
    enableGold = false;
    # bootstrap is easier w/static
    enableShared = false;
  };

  build =
    let
      # ${libc.src}/sysdeps/unix/sysv/linux/loongarch/lp64/libnsl.abilist does not exist!
      withLibnsl = !stdenv.hostPlatform.isLoongArch64;
    in
    stdenv.mkDerivation {
      name = "stdenv-bootstrap-tools";

      meta = {
        # Increase priority to unblock botpkgs-unstable
        # https://github.com/nervosys/Botnix/pull/104679#issuecomment-732267288
        schedulingPriority = 200;
      };

      nativeBuildInputs = [ buildPackages.nukeReferences buildPackages.cpio ];

      buildCommand = ''
        set -x
        mkdir -p $out/bin $out/lib $out/libexec

      '' + (if (stdenv.hostPlatform.libc == "glibc") then ''
        # Copy what we need of Glibc.
        cp -d ${libc.out}/lib/ld*.so* $out/lib
        cp -d ${libc.out}/lib/libc*.so* $out/lib
        cp -d ${libc.out}/lib/libc_nonshared.a $out/lib
        cp -d ${libc.out}/lib/libm*.so* $out/lib
        cp -d ${libc.out}/lib/libdl*.so* $out/lib
        cp -d ${libc.out}/lib/librt*.so*  $out/lib
        cp -d ${libc.out}/lib/libpthread*.so* $out/lib
      '' + lib.optionalString withLibnsl ''
        cp -d ${libc.out}/lib/libnsl*.so* $out/lib
      '' + ''
        cp -d ${libc.out}/lib/libutil*.so* $out/lib
        cp -d ${libc.out}/lib/libnss*.so* $out/lib
        cp -d ${libc.out}/lib/libresolv*.so* $out/lib
        # Copy all runtime files to enable non-PIE, PIE, static PIE and profile-generated builds
        cp -d ${libc.out}/lib/*.o $out/lib

        # Hacky compat with our current unpack-bootstrap-tools.sh
        ln -s librt.so "$out"/lib/librt-dummy.so

        cp -rL ${libc.dev}/include $out
        chmod -R u+w "$out"

        # libc can contain linker scripts: find them, copy their deps,
        # and get rid of absolute paths (nuke-refs would make them useless)
        local lScripts=$(grep --files-with-matches --max-count=1 'GNU ld script' -R "$out/lib")
        cp -d -t "$out/lib/" $(cat $lScripts | tr " " "\n" | grep -F '${libc.out}' | sort -u)
        for f in $lScripts; do
          substituteInPlace "$f" --replace '${libc.out}/lib/' ""
        done

        # Hopefully we won't need these.
        rm -rf $out/include/mtd $out/include/rdma $out/include/sound $out/include/video
        find $out/include -name .install -exec rm {} \;
        find $out/include -name ..install.cmd -exec rm {} \;
        mv $out/include $out/include-glibc
    '' else if (stdenv.hostPlatform.libc == "musl") then ''
        # Copy what we need from musl
        cp ${libc.out}/lib/* $out/lib
        cp -rL ${libc.dev}/include $out
        chmod -R u+w "$out"

        rm -rf $out/include/mtd $out/include/rdma $out/include/sound $out/include/video
        find $out/include -name .install -exec rm {} \;
        find $out/include -name ..install.cmd -exec rm {} \;
        mv $out/include $out/include-libc
    '' else throw "unsupported libc for bootstrap tools")
    + ''
        # Copy coreutils, bash, etc.
        cp -d ${coreutilsMinimal.out}/bin/* $out/bin
        (cd $out/bin && rm vdir dir sha*sum pinky factor pathchk runcon shuf who whoami shred users)

        cp ${bash.out}/bin/bash $out/bin
        cp ${findutils.out}/bin/find $out/bin
        cp ${findutils.out}/bin/xargs $out/bin
        cp -d ${diffutils.out}/bin/* $out/bin
        cp -d ${gnused.out}/bin/* $out/bin
        cp -d ${gnugrep.out}/bin/grep $out/bin
        cp ${gawk.out}/bin/gawk $out/bin
        cp -d ${gawk.out}/bin/awk $out/bin
        cp ${tarMinimal.out}/bin/tar $out/bin
        cp ${gzip.out}/bin/.gzip-wrapped $out/bin/gzip
        cp ${bzip2.bin}/bin/bzip2 $out/bin
        cp -d ${gnumake.out}/bin/* $out/bin
        cp -d ${patch}/bin/* $out/bin
        cp ${patchelf}/bin/* $out/bin

        cp -d ${gnugrep.pcre2.out}/lib/libpcre2*.so* $out/lib # needed by grep

        # Copy what we need of GCC.
        cp -d ${bootGCC.out}/bin/gcc $out/bin
        cp -d ${bootGCC.out}/bin/cpp $out/bin
        cp -d ${bootGCC.out}/bin/g++ $out/bin
        cp    ${bootGCC.lib}/lib/libgcc_s.so* $out/lib
        cp -d ${bootGCC.lib}/lib/libstdc++.so* $out/lib
        cp -d ${bootGCC.out}/lib/libssp.a* $out/lib
        cp -d ${bootGCC.out}/lib/libssp_nonshared.a $out/lib
        cp -rd ${bootGCC.out}/lib/gcc $out/lib
        chmod -R u+w $out/lib
        rm -f $out/lib/gcc/*/*/include*/linux
        rm -f $out/lib/gcc/*/*/include*/sound
        rm -rf $out/lib/gcc/*/*/include*/root
        rm -f $out/lib/gcc/*/*/include-fixed/asm
        rm -rf $out/lib/gcc/*/*/plugin
        #rm -f $out/lib/gcc/*/*/*.a
        cp -rd ${bootGCC.out}/libexec/* $out/libexec
        chmod -R u+w $out/libexec
        rm -rf $out/libexec/gcc/*/*/plugin
        mkdir -p $out/include
        cp -rd ${bootGCC.out}/include/c++ $out/include
        chmod -R u+w $out/include
        rm -rf $out/include/c++/*/ext/pb_ds
        rm -rf $out/include/c++/*/ext/parallel

        cp -d ${gmpxx.out}/lib/libgmp*.so* $out/lib
        cp -d ${isl.out}/lib/libisl*.so* $out/lib
        cp -d ${mpfr.out}/lib/libmpfr*.so* $out/lib
        cp -d ${libmpc.out}/lib/libmpc*.so* $out/lib
        cp -d ${zlib.out}/lib/libz.so* $out/lib

      '' + lib.optionalString (stdenv.hostPlatform.isRiscV) ''
        # libatomic is required on RiscV platform for C/C++ atomics and pthread
        # even though they may be translated into native instructions.
        cp -d ${bootGCC.out}/lib/libatomic.a* $out/lib

      '' + ''
        cp -d ${bzip2.out}/lib/libbz2.so* $out/lib

        # Copy binutils.
        for i in as ld ar ranlib nm strip readelf objdump; do
          cp ${bootBinutils.out}/bin/$i $out/bin
        done
        cp -r '${lib.getLib binutils.bintools}'/lib/* "$out/lib/"

        chmod -R u+w $out

        # Strip executables even further.
        for i in $out/bin/* $out/libexec/gcc/*/*/*; do
            if test -x $i -a ! -L $i; then
                chmod +w $i
                $STRIP -s $i || true
            fi
        done

        nuke-refs $out/bin/*
        nuke-refs $out/lib/*
        nuke-refs $out/lib/*/*
        nuke-refs $out/libexec/gcc/*/*/*
        nuke-refs $out/lib/gcc/*/*/*
        nuke-refs $out/lib/gcc/*/*/include-fixed/*{,/*}

        mkdir $out/.pack
        mv $out/* $out/.pack
        mv $out/.pack $out/pack

        mkdir $out/on-server
        XZ_OPT="-9 -e" tar cvJf $out/on-server/bootstrap-tools.tar.xz --hard-dereference --sort=name --numeric-owner --owner=0 --group=0 --mtime=@1 -C $out/pack .
        cp ${busyboxMinimal}/bin/busybox $out/on-server
        chmod u+w $out/on-server/busybox
        nuke-refs $out/on-server/busybox
      ''; # */

      # The result should not contain any references (store paths) so
      # that we can safely copy them out of the store and to other
      # locations in the store.
      allowedReferences = [];
    };

  dist = stdenv.mkDerivation {
    name = "stdenv-bootstrap-tools";

    meta = {
      # Increase priority to unblock botpkgs-unstable
      # https://github.com/nervosys/Botnix/pull/104679#issuecomment-732267288
      schedulingPriority = 200;
    };

    buildCommand = ''
      mkdir -p $out/nix-support
      echo "file tarball ${build}/on-server/bootstrap-tools.tar.xz" >> $out/nix-support/hydra-build-products
      echo "file busybox ${build}/on-server/busybox" >> $out/nix-support/hydra-build-products
    '';
  };

  bootstrapFiles = {
    # Make them their own store paths to test that busybox still works when the binary is named /nix/store/HASH-busybox
    busybox = runCommand "busybox" {} "cp ${build}/on-server/busybox $out";
    bootstrapTools = runCommand "bootstrap-tools.tar.xz" {} "cp ${build}/on-server/bootstrap-tools.tar.xz $out";
  };

  bootstrapTools =
    let extraAttrs = lib.optionalAttrs
      config.contentAddressedByDefault
      {
        __contentAddressed = true;
        outputHashAlgo = "sha256";
        outputHashMode = "recursive";
      };
    in
    if (stdenv.hostPlatform.libc == "glibc") then
    import ./bootstrap-tools {
      inherit (stdenv.buildPlatform) system; # Used to determine where to build
      inherit bootstrapFiles extraAttrs;
    }
    else if (stdenv.hostPlatform.libc == "musl") then
    import ./bootstrap-tools-musl {
      inherit (stdenv.buildPlatform) system; # Used to determine where to build
      inherit bootstrapFiles extraAttrs;
    }
    else throw "unsupported libc";

  test = derivation {
    name = "test-bootstrap-tools";
    inherit (stdenv.hostPlatform) system; # We cannot "cross test"
    builder = bootstrapFiles.busybox;
    args = [ "ash" "-e" "-c" "eval \"$buildCommand\"" ];

    buildCommand = ''
      export PATH=${bootstrapTools}/bin

      ls -l
      mkdir $out
      mkdir $out/bin
      sed --version
      find --version
      diff --version
      patch --version
      make --version
      awk --version
      grep --version
      gcc --version

    '' + lib.optionalString (stdenv.hostPlatform.libc == "glibc") ''
      rtld=$(echo ${bootstrapTools}/lib/${builtins.unsafeDiscardStringContext /* only basename */ (builtins.baseNameOf binutils.dynamicLinker)})
      libc_includes=${bootstrapTools}/include-glibc
    '' + lib.optionalString (stdenv.hostPlatform.libc == "musl") ''
      rtld=$(echo ${bootstrapTools}/lib/ld-musl*.so.?)
      libc_includes=${bootstrapTools}/include-libc
    '' + ''
      # path to version-specific libraries, like libstdc++.so
      cxx_libs=$(echo ${bootstrapTools}/lib/gcc/*/*)
      export CPP="cpp -idirafter $libc_includes -B${bootstrapTools}"
      export  CC="gcc -idirafter $libc_includes -B${bootstrapTools} -Wl,-dynamic-linker,$rtld -Wl,-rpath,${bootstrapTools}/lib -Wl,-rpath,$cxx_libs"
      export CXX="g++ -idirafter $libc_includes -B${bootstrapTools} -Wl,-dynamic-linker,$rtld -Wl,-rpath,${bootstrapTools}/lib -Wl,-rpath,$cxx_libs"

      echo '#include <stdio.h>' >> foo.c
      echo '#include <limits.h>' >> foo.c
      echo 'int main() { printf("Hello World\\n"); return 0; }' >> foo.c
      $CC -o $out/bin/foo foo.c
      $out/bin/foo

      echo '#include <iostream>' >> bar.cc
      echo 'int main() { std::cout << "Hello World\\n"; }' >> bar.cc
      $CXX -v -o $out/bin/bar bar.cc
      $out/bin/bar

      tar xvf ${hello.src}
      cd hello-*
      ./configure --prefix=$out
      make
      make install
    '';
  };
}
