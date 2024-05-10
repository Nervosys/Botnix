/* Hydra job to build a tarball for Botpkgs from a Git checkout.  It
   also builds the documentation and tests whether the Nix expressions
   evaluate correctly. */

{ botpkgs
, officialRelease
, supportedSystems
, pkgs ? import botpkgs.outPath {}
, nix ? pkgs.nix
, lib-tests ? import ../../lib/tests/release.nix { inherit pkgs; }
}:

pkgs.releaseTools.sourceTarball {
  name = "botpkgs-tarball";
  src = botpkgs;

  inherit officialRelease;
  version = pkgs.lib.fileContents ../../.version;
  versionSuffix = "pre${
    if botpkgs ? lastModified
    then builtins.substring 0 8 (botpkgs.lastModifiedDate or botpkgs.lastModified)
    else toString (botpkgs.revCount or 0)}.${botpkgs.shortRev or "dirty"}";

  buildInputs = with pkgs; [ nix.out jq lib-tests brotli ];

  configurePhase = ''
    eval "$preConfigure"
    releaseName=botpkgs-$VERSION$VERSION_SUFFIX
    echo -n $VERSION_SUFFIX > .version-suffix
    echo -n ${botpkgs.rev or botpkgs.shortRev or "dirty"} > .git-revision
    echo "release name is $releaseName"
    echo "git-revision is $(cat .git-revision)"
  '';

  requiredSystemFeatures = [ "big-parallel" ]; # 1 thread but ~36G RAM (!) see #227945

  botpkgs-basic-release-checks = import ./botpkgs-basic-release-checks.nix
   { inherit nix pkgs botpkgs supportedSystems; };

  dontBuild = false;

  doCheck = true;

  checkPhase = ''
    set -o pipefail

    export NIX_STATE_DIR=$TMPDIR
    export NIX_PATH=botpkgs=$TMPDIR/barf.nix
    opts=(--option build-users-group "")
    nix-store --init

    echo "checking eval-release.nix"
    nix-instantiate --eval --strict --show-trace ./maintainers/scripts/eval-release.nix > /dev/null

    echo "checking find-tarballs.nix"
    nix-instantiate --readonly-mode --eval --strict --show-trace --json \
       ./maintainers/scripts/find-tarballs.nix \
      --arg expr 'import ./maintainers/scripts/all-tarballs.nix' > $TMPDIR/tarballs.json
    nrUrls=$(jq -r '.[].url' < $TMPDIR/tarballs.json | wc -l)
    echo "found $nrUrls URLs"
    if [ "$nrUrls" -lt 10000 ]; then
      echo "suspiciously low number of URLs"
      exit 1
    fi

    echo "generating packages.json"
    mkdir -p $out/nix-support
    echo -n '{"version":2,"packages":' > tmp
    nix-env -f . -I botpkgs=$src -qa --meta --json --show-trace --arg config 'import ${./packages-config.nix}' "''${opts[@]}" >> tmp
    echo -n '}' >> tmp
    packages=$out/packages.json.br
    < tmp sed "s|$(pwd)/||g" | jq -c | brotli -9 > $packages
    rm tmp

    echo "file json-br $packages" >> $out/nix-support/hydra-build-products
  '';

  distPhase = ''
    mkdir -p $out/tarballs
    mkdir ../$releaseName
    cp -prd . ../$releaseName
    (cd .. && tar cfa $out/tarballs/$releaseName.tar.xz $releaseName) || false
  '';

  meta = {
    maintainers = [ ];
  };
}
