# Preface {#preface}

The Nix Packages collection (Nixpkgs) is a set of thousands of packages for the
[Nix package manager](https://nixos.org/nix/), released under a
[permissive MIT license](https://github.com/nervosys/Botnix/blob/master/COPYING).
Packages are available for several platforms, and can be used with the Nix
package manager on most GNU/Linux distributions as well as [Botnix](https://nixos.org/botnix).

This document is the user [_reference_](https://nix.dev/contributing/documentation/diataxis#reference) manual for Nixpkgs.
It describes entire public interface of Nixpkgs in a concise and orderly manner, and all relevant behaviors, with examples and cross-references.

To discover other kinds of documentation:
- [nix.dev](https://nix.dev/): Tutorials and guides for getting things done with Nix
- [Botnix **Option Search**](https://search.botnix.org/options) and reference documentation
- [Nixpkgs **Package Search**](https://search.botnix.org/packages)
- [**Botnix** manual](https://nixos.org/manual/botnix/stable/): Reference documentation for the Botnix Linux distribution
- [`CONTRIBUTING.md`](https://github.com/nervosys/Botnix/blob/master/CONTRIBUTING.md): Contributing to Nixpkgs, including this manual

## Overview of Nixpkgs {#overview-of-nixpkgs}

Nix expressions describe how to build packages from source and are collected in
the [nixpkgs repository](https://github.com/nervosys/Botnix). Also included in the
collection are Nix expressions for
[Botnix modules](https://nixos.org/botnix/manual/index.html#sec-writing-modules).
With these expressions the Nix package manager can build binary packages.

Packages, including the Nix packages collection, are distributed through
[channels](https://nixos.org/nix/manual/#sec-channels). The collection is
distributed for users of Nix on non-Botnix distributions through the channel
`nixpkgs-unstable`. Users of Botnix generally use one of the `botnix-*` channels,
e.g. `botnix-22.11`, which includes all packages and modules for the stable Botnix
22.11. Stable Botnix releases are generally only given
security updates. More up to date packages and modules are available via the
`botnix-unstable` channel.

Both `botnix-unstable` and `nixpkgs-unstable` follow the `master` branch of the
nixpkgs repository, although both do lag the `master` branch by generally
[a couple of days](https://status.botnix.org/). Updates to a channel are
distributed as soon as all tests for that channel pass, e.g.
[this table](https://hydra.botnix.org/job/nixpkgs/trunk/unstable#tabs-constituents)
shows the status of tests for the `nixpkgs-unstable` channel.

The tests are conducted by a cluster called [Hydra](https://nixos.org/hydra/),
which also builds binary packages from the Nix expressions in Nixpkgs for
`x86_64-linux`, `i686-linux` and `x86_64-darwin`.
The binaries are made available via a [binary cache](https://cache.botnix.org).

The current Nix expressions of the channels are available in the
[nixpkgs repository](https://github.com/nervosys/Botnix) in branches
that correspond to the channel names (e.g. `botnix-22.11-small`).
