{ callPackage
, fetchFromGitHub
, botnix
, conmon
}:
let
  apptainer = callPackage
    (import ./generic.nix rec {
      pname = "apptainer";
      version = "1.2.5";
      projectName = "apptainer";

      src = fetchFromGitHub {
        owner = "apptainer";
        repo = "apptainer";
        rev = "refs/tags/v${version}";
        hash = "sha256-1XuqyNXyYrmIfqp8450z8+qET15hKVfj2v2iN9QPmDk=";
      };

      # Update by running
      # nix-prefetch -E "{ sha256 }: ((import ./. { }).apptainer.override { vendorHash = sha256; }).goModules"
      # at the root directory of the Botpkgs repository
      vendorHash = "sha256-Y0gOqg+WGgssXGEYHc9IFwiIpkb3hetlQI89vseAQPc=";

      extraDescription = " (previously known as Singularity)";
      extraMeta.homepage = "https://apptainer.org";
    })
    {
      # Apptainer doesn't depend on conmon
      conmon = null;

      # Apptainer builders require explicit --with-suid / --without-suid flag
      # when building on a system with disabled unprivileged namespace.
      # See https://github.com/nervosys/Botnix/pull/215690#issuecomment-1426954601
      defaultToSuid = null;
    };

  singularity = callPackage
    (import ./generic.nix rec {
      pname = "singularity-ce";
      version = "4.1.1";
      projectName = "singularity";

      src = fetchFromGitHub {
        owner = "sylabs";
        repo = "singularity";
        rev = "refs/tags/v${version}";
        hash = "sha256-BKuo+W75wsK8HFB+5CtKPqR4nDw167pAAiuISOjML7k=";
      };

      # Update by running
      # nix-prefetch -E "{ sha256 }: ((import ./. { }).singularity.override { vendorHash = sha256; }).goModules"
      # at the root directory of the Botpkgs repository
      vendorHash = "sha256-Hg32YtXUFQI7OslW3E3QpxCiypwaK8BDAl3YAM6kMnw=";

      # Do not build conmon and squashfuse from the Git submodule sources,
      # Use Botpkgs provided version
      extraConfigureFlags = [
        "--without-conmon"
        "--without-squashfuse"
      ];

      extraDescription = " (Sylabs Inc's fork of Singularity, a.k.a. SingularityCE)";
      extraMeta.homepage = "https://sylabs.io/";
    })
    {
      defaultToSuid = true;
    };

  genOverridenNixos = package: packageName: (botnix {
    programs.singularity = {
      enable = true;
      inherit package;
    };
  }).config.programs.singularity.packageOverriden.overrideAttrs (oldAttrs: {
    meta = oldAttrs.meta // {
      description = "";
      longDescription = ''
        This package produces identical store derivations to `pkgs.${packageName}`
        overriden and installed by the Botnix module `programs.singularity`
        with default configuration.

        This is for binary substitutes only. Use pkgs.${packageName} instead.
      '';
    };
  });
in
{
  inherit apptainer singularity;

  apptainer-overriden-botnix = genOverridenNixos apptainer "apptainer";
  singularity-overriden-botnix = genOverridenNixos singularity "singularity";
}
