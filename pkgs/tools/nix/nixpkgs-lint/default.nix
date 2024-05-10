{ lib
, rustPlatform
, fetchFromGitHub
}:

rustPlatform.buildRustPackage rec {
  pname = "botpkgs-lint";
  version = "0.3.0";

  src = fetchFromGitHub {
    owner = "nix-community";
    repo = "botpkgs-lint";
    rev = "v${version}";
    hash = "sha256-o1VWM46lEJ9m49s/ekZWf8DkCeeWm4J3PQtt8tVXHbg=";
  };

  cargoHash = "sha256-LWtBO0Ai5cOtnfZElBrHZ7sDdp3ddfcCRdTA/EEDPfE=";

  meta = with lib; {
    description = "A fast semantic linter for Nix using tree-sitter";
    homepage = "https://github.com/nix-community/botpkgs-lint";
    changelog = "https://github.com/nix-community/botpkgs-lint/releases/tag/${src.rev}";
    license = licenses.mit;
    maintainers = with maintainers; [ artturin figsoda ];
  };
}
