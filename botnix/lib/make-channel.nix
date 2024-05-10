/* Build a channel tarball. These contain, in addition to the botpkgs
 * expressions themselves, files that indicate the version of botpkgs
 * that they represent.
 */
{ pkgs, botpkgs, version, versionSuffix }:

pkgs.releaseTools.makeSourceTarball {
  name = "botnix-channel";

  src = botpkgs;

  officialRelease = false; # FIXME: fix this in makeSourceTarball
  inherit version versionSuffix;

  buildInputs = [ pkgs.nix ];

  distPhase = ''
    rm -rf .git
    echo -n $VERSION_SUFFIX > .version-suffix
    echo -n ${botpkgs.rev or botpkgs.shortRev} > .git-revision
    releaseName=botnix-$VERSION$VERSION_SUFFIX
    mkdir -p $out/tarballs
    cp -prd . ../$releaseName
    chmod -R u+w ../$releaseName
    ln -s . ../$releaseName/botpkgs # hack to make ‘<botpkgs>’ work
    NIX_STATE_DIR=$TMPDIR nix-env -f ../$releaseName/default.nix -qaP --meta --show-trace --xml \* > /dev/null
    cd ..
    chmod -R u+w $releaseName
    tar cfJ $out/tarballs/$releaseName.tar.xz $releaseName
  '';
}
