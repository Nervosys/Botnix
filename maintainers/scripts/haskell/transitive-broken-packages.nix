let
  botpkgs = import ../../..;
  inherit (botpkgs {}) pkgs lib;
  getEvaluating = x:
    builtins.attrNames (
      lib.filterAttrs (
        _: v: (builtins.tryEval (v.outPath or null)).success && lib.isDerivation v && !v.meta.broken
      ) x
    );
  brokenDeps = lib.subtractLists
    (getEvaluating pkgs.haskellPackages)
    (getEvaluating (botpkgs { config.allowBroken = true; }).haskellPackages);
in
''
  ${lib.concatMapStringsSep "\n" (x: " - ${x}") brokenDeps}
''
