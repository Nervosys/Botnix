{ stdenv
, lib
, callPackage
, fetchurl
, nixosTests
, srcOnly
, isInsiders ? false
# sourceExecutableName is the name of the binary in the source archive over
# which we have no control and it is needed to run the insider version as
# documented in https://botnix.wiki/wiki/Visual_Studio_Code#Insiders_Build
# On MacOS the insider binary is still called code instead of code-insiders as
# of 2023-08-06.
, sourceExecutableName ? "code" + lib.optionalString (isInsiders && stdenv.isLinux) "-insiders"
, commandLineArgs ? ""
, useVSCodeRipgrep ? stdenv.isDarwin
}:

let
  inherit (stdenv.hostPlatform) system;
  throwSystem = throw "Unsupported system: ${system}";

  plat = {
    x86_64-linux = "linux-x64";
    x86_64-darwin = "darwin";
    aarch64-linux = "linux-arm64";
    aarch64-darwin = "darwin-arm64";
    armv7l-linux = "linux-armhf";
  }.${system} or throwSystem;

  archive_fmt = if stdenv.isDarwin then "zip" else "tar.gz";

  sha256 = {
    x86_64-linux = "0nffz9xqm1iny7sqi1pkmnfcski15qsycw9gxir18j51kfzz50wf";
    x86_64-darwin = "082m2wwd67ayjadlywqimnmdm8imw6lz0rd8rnwjd2sjksxnrsk8";
    aarch64-linux = "0wlm8ajm1xw8lpmnbkzkgvaakfa9gacwi7m2fdyc4822rq7fn09b";
    aarch64-darwin = "1rgcljj97f551yr0q5f0vxdkvbhxrbyqrw85gb6qfxpg5d0l7y4f";
    armv7l-linux = "1wpslrysi8a6rnx99lq16zx277lnmqjp02q6gxmkpcvrvw27m6yj";
  }.${system} or throwSystem;
in
  callPackage ./generic.nix rec {
    # Please backport all compatible updates to the stable release.
    # This is important for the extension ecosystem.
    version = "1.86.1";
    pname = "vscode" + lib.optionalString isInsiders "-insiders";

    # This is used for VS Code - Remote SSH test
    rev = "31c37ee8f63491495ac49e43b8544550fbae4533";

    executableName = "code" + lib.optionalString isInsiders "-insiders";
    longName = "Visual Studio Code" + lib.optionalString isInsiders " - Insiders";
    shortName = "Code" + lib.optionalString isInsiders " - Insiders";
    inherit commandLineArgs useVSCodeRipgrep sourceExecutableName;

    src = fetchurl {
      name = "VSCode_${version}_${plat}.${archive_fmt}";
      url = "https://update.code.visualstudio.com/${version}/${plat}/stable";
      inherit sha256;
    };

    # We don't test vscode on CI, instead we test vscodium
    tests = {};

    sourceRoot = "";

    # As tests run without networking, we need to download this for the Remote SSH server
    vscodeServer = srcOnly {
      name = "vscode-server-${rev}.tar.gz";
      src = fetchurl {
        name = "vscode-server-${rev}.tar.gz";
        url = "https://update.code.visualstudio.com/commit:${rev}/server-linux-x64/stable";
        sha256 = "1hq6i51d1dhpippc8gmhygw3kj9cx021y54ga58l5b80wvg2cf1y";
      };
    };

    tests = { inherit (nixosTests) vscode-remote-ssh; };

    updateScript = ./update-vscode.sh;

    # Editing the `code` binary within the app bundle causes the bundle's signature
    # to be invalidated, which prevents launching starting with macOS Ventura, because VS Code is notarized.
    # See https://eclecticlight.co/2022/06/17/app-security-changes-coming-in-ventura/ for more information.
    dontFixup = stdenv.isDarwin;

    meta = with lib; {
      description = ''
        Open source source code editor developed by Microsoft for Windows,
        Linux and macOS
      '';
      mainProgram = "code";
      longDescription = ''
        Open source source code editor developed by Microsoft for Windows,
        Linux and macOS. It includes support for debugging, embedded Git
        control, syntax highlighting, intelligent code completion, snippets,
        and code refactoring. It is also customizable, so users can change the
        editor's theme, keyboard shortcuts, and preferences
      '';
      homepage = "https://code.visualstudio.com/";
      downloadPage = "https://code.visualstudio.com/Updates";
      license = licenses.unfree;
      maintainers = with maintainers; [ eadwu synthetica amaxine bobby285271 Enzime ];
      platforms = [ "x86_64-linux" "x86_64-darwin" "aarch64-darwin" "aarch64-linux" "armv7l-linux" ];
    };
  }
