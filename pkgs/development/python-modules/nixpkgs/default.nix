{ lib
, buildPythonPackage
, fetchPypi
, pbr
, pythonix
, pythonAtLeast
}:

buildPythonPackage rec {
  pname = "botpkgs";
  version = "0.2.4";
  format = "setuptools";
  disabled = ! pythonAtLeast "3.5";

  src = fetchPypi {
    inherit pname version;
    sha256 = "0dlvq4bpamhlva86042wlc0xxfsxlpdgm2adfb1c6y3vjgbm0nvd";
  };

  buildInputs = [ pbr ];
  propagatedBuildInputs = [ pythonix ];

  # does not have any tests
  doCheck = false;
  pythonImportsCheck = [ "botpkgs" ];

  meta = with lib; {
    description = "Allows to `from botpkgs import` stuff in interactive Python sessions";
    homepage = "https://github.com/t184256/botpkgs-python-importer";
    license = licenses.mit;
    maintainers = with maintainers; [ t184256 ];
  };

}
