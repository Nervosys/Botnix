{ stdenv
, lib
, buildPythonPackage
, pythonOlder
, fetchFromGitHub
, cmake
, boost
, eigen
, python
, catch
, numpy
, pytestCheckHook
, libxcrypt
, makeSetupHook
}: let
  setupHook = makeSetupHook {
    name = "pybind11-setup-hook";
    substitutions = {
      out = placeholder "out";
      pythonInterpreter = python.pythonOnBuildForHost.interpreter;
      pythonIncludeDir = "${python}/include/python${python.pythonVersion}";
      pythonSitePackages = "${python}/${python.sitePackages}";
    };
  } ./setup-hook.sh;

  # clang 16 defaults to C++17, which results in the use of aligned allocations by pybind11.
  # libc++ supports aligned allocations via `posix_memalign`, which is available since 10.6,
  # but clang has a check hard-coded requiring 10.13 because that’s when Apple first shipped a
  # support for C++17 aligned allocations on macOS.
  # Tell clang we’re targeting 10.13 on x86_64-darwin while continuing to use the default SDK.
  stdenv' = if stdenv.isDarwin && stdenv.isx86_64
    then python.stdenv.override (oldStdenv: {
      buildPlatform = oldStdenv.buildPlatform // { darwinMinVersion = "10.13"; };
      targetPlatform = oldStdenv.targetPlatform // { darwinMinVersion = "10.13"; };
      hostPlatform = oldStdenv.hostPlatform // { darwinMinVersion = "10.13"; };
    })
    else python.stdenv;
in buildPythonPackage rec {
  pname = "pybind11";
  version = "2.11.1";
  format = "setuptools";

  src = fetchFromGitHub {
    owner = "pybind";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-sO/Fa+QrAKyq2EYyYMcjPrYI+bdJIrDoj6L3JHoDo3E=";
  };

  postPatch = ''
    sed -i "/^timeout/d" pyproject.toml
  '';

  nativeBuildInputs = [ cmake ];
  buildInputs = lib.optionals (pythonOlder "3.9") [ libxcrypt ];
  propagatedBuildInputs = [ setupHook ];

  stdenv = stdenv';

  dontUseCmakeBuildDir = true;

  # Don't build tests if not needed, read the doInstallCheck value at runtime
  preConfigure = ''
    if [ -n "$doInstallCheck" ]; then
      cmakeFlagsArray+=("-DBUILD_TESTING=ON")
    fi
  '';

  cmakeFlags = [
    "-DBoost_INCLUDE_DIR=${lib.getDev boost}/include"
    "-DEIGEN3_INCLUDE_DIR=${lib.getDev eigen}/include/eigen3"
  ] ++ lib.optionals (python.isPy3k && !stdenv.cc.isClang) [
    "-DPYBIND11_CXX_STANDARD=-std=c++17"
  ];

  postBuild = ''
    # build tests
    make -j $NIX_BUILD_CORES
  '';

  postInstall = ''
    make install
    # Symlink the CMake-installed headers to the location expected by setuptools
    mkdir -p $out/include/${python.libPrefix}
    ln -sf $out/include/pybind11 $out/include/${python.libPrefix}/pybind11
  '';

  nativeCheckInputs = [
    catch
    numpy
    pytestCheckHook
  ];

  disabledTestPaths = [
    # require dependencies not available in botpkgs
    "tests/test_embed/test_trampoline.py"
    "tests/test_embed/test_interpreter.py"
    # numpy changed __repr__ output of numpy dtypes
    "tests/test_numpy_dtypes.py"
    # no need to test internal packaging
    "tests/extra_python_package/test_files.py"
    # tests that try to parse setuptools stdout
    "tests/extra_setuptools/test_setuphelper.py"
  ];

  disabledTests = lib.optionals stdenv.isDarwin [
    # expects KeyError, gets RuntimeError
    # https://github.com/pybind/pybind11/issues/4243
    "test_cross_module_exception_translator"
  ];

  hardeningDisable = lib.optional stdenv.hostPlatform.isMusl "fortify";

  meta = with lib; {
    homepage = "https://github.com/pybind/pybind11";
    changelog = "https://github.com/pybind/pybind11/blob/${src.rev}/docs/changelog.rst";
    description = "Seamless operability between C++11 and Python";
    longDescription = ''
      Pybind11 is a lightweight header-only library that exposes
      C++ types in Python and vice versa, mainly to create Python
      bindings of existing C++ code.
    '';
    license = licenses.bsd3;
    maintainers = with maintainers; [ yuriaisaka dotlambda ];
  };
}
