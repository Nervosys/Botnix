{ lib
, formats
, stdenvNoCC
, fetchFromGitHub
, qtgraphicaleffects
  /* An example of how you can override the background on the Botnix logo
  *
  *  environment.systemPackages = [
  *    (pkgs.where-is-my-sddm-theme.override {
  *      themeConfig.General = {
  *        background = "${pkgs.botnix-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
  *        backgroundMode = "none";
  *      };
  *    })
  *  ];
  */
, themeConfig ? null
}:

let
  user-cfg = (formats.ini { }).generate "theme.conf.user" themeConfig;
in

stdenvNoCC.mkDerivation rec {
  pname = "where-is-my-sddm-theme";
  version = "1.6.0";

  src = fetchFromGitHub {
    owner = "stepanzubkov";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-EK0bB2dRXNtDKFiyf+nMoDq9XK2f3PFwoNbQDZamB3Y=";
  };

  propagatedUserEnvPkgs = [ qtgraphicaleffects ];

  installPhase = ''
    mkdir -p $out/share/sddm/themes/
    cp -r where_is_my_sddm_theme/ $out/share/sddm/themes/
  '' + lib.optionalString (lib.isAttrs themeConfig) ''
    ln -sf ${user-cfg} $out/share/sddm/themes/where_is_my_sddm_theme/theme.conf.user
  '';

  meta = with lib; {
    description = "The most minimalistic SDDM theme among all themes";
    homepage = "https://github.com/stepanzubkov/where-is-my-sddm-theme";
    license = licenses.mit;
    maintainers = with maintainers; [ name-snrl ];
  };
}
