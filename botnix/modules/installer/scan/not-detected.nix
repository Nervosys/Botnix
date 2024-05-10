# Enables non-free firmware on devices not recognized by `botnix-generate-config`.
{ lib, ... }:

{
  hardware.enableRedistributableFirmware = lib.mkDefault true;
}
