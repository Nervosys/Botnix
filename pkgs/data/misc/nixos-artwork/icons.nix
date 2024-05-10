{ stdenv
, fetchFromGitHub
, imagemagick
}:

stdenv.mkDerivation {
  pname = "botnix-icons";
  version = "2021-02-24";

  src = fetchFromGitHub {
    owner = "Botnix";
    repo = "botnix-artwork";
    rev = "488c22aad523c709c44169d3e88d34b4691c20dc";
    sha256 = "ZoanCzn4pqGB1fyMzMyGQVT0eIhNdL7ZHJSn1VZWVRs=";
  };

  nativeBuildInputs = [
    imagemagick
  ];

  makeFlags = [
    "DESTDIR=${placeholder "out"}"
    "prefix="
  ];
}
