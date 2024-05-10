# This module adds the calamares installer to the basic graphical Botnix
# installation CD.

{ pkgs, ... }:
let
  calamares-botnix-autostart = pkgs.makeAutostartItem { name = "io.calamares.calamares"; package = pkgs.calamares-botnix; };
in
{
  imports = [ ./installation-cd-graphical-base.nix ];

  environment.systemPackages = with pkgs; [
    # Calamares for graphical installation
    libsForQt5.kpmcore
    calamares-botnix
    calamares-botnix-autostart
    calamares-botnix-extensions
    # Get list of locales
    glibcLocales
  ];

  # Support choosing from any locale
  i18n.supportedLocales = [ "all" ];
}
