{ lib
, buildPythonPackage
, fetchFromGitHub
, unstableGitUpdater
, poetry-core
, nixops
}:

buildPythonPackage {
  pname = "botnix-modules-contrib";
  version = "unstable-2021-01-20";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "nix-community";
    repo = "botnix-modules-contrib";
    rev = "81a1c2ef424dcf596a97b2e46a58ca73a1dd1ff8";
    hash = "sha256-/RSStpkAxWpUB5saQ8CmQZljFjJyUMOrR1+GiHJR2Tg=";
  };

  postPatch = ''
    substituteInPlace pyproject.toml \
    --replace poetry.masonry.api poetry.core.masonry.api \
    --replace "poetry>=" "poetry-core>="
  '';

  nativeBuildInputs = [
    poetry-core
  ];

  buildInputs = [
    nixops
  ];

  pythonImportsCheck = [ "nixos_modules_contrib" ];

  passthru.updateScript = unstableGitUpdater {};

  meta = with lib; {
    description = "Useful Botnix modules which may not belong in the Botpkgs repository itself";
    homepage = "https://github.com/nix-community/botnix-modules-contrib";
    license = licenses.lgpl3;
    maintainers = [];
  };
}
