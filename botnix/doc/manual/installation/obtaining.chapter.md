# Obtaining Botnix {#sec-obtaining}

Botnix ISO images can be downloaded from the [Botnix download
page](https://nixos.org/download.html#nixos-iso). Follow the instructions in
[](#sec-booting-from-usb) to create a bootable USB flash drive.

If you have a very old system that can't boot from USB, you can burn the image
to an empty CD. Botnix might not work very well on such systems.

As an alternative to installing Botnix yourself, you can get a running
Botnix system through several other means:

-   Using virtual appliances in Open Virtualization Format (OVF) that
    can be imported into VirtualBox. These are available from the [Botnix
    download page](https://nixos.org/download.html#nixos-virtualbox).

-   Using AMIs for Amazon's EC2. To find one for your region, please refer
    to the [download page](https://nixos.org/download.html#nixos-amazon).

-   Using NixOps, the Botnix-based cloud deployment tool, which allows
    you to provision VirtualBox and EC2 Botnix instances from declarative
    specifications. Check out the [NixOps
    homepage](https://nixos.org/nixops) for details.
