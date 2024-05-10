{ substituteAll
, perl
, shadow
, util-linux
, configurationDirectory ? "/etc/botnix-containers"
, stateDirectory ? "/var/lib/botnix-containers"
, nixosTests
}:

substituteAll {
    name = "botnix-container";
    dir = "bin";
    isExecutable = true;
    src = ./botnix-container.pl;
    perl = perl.withPackages (p: [ p.FileSlurp ]);
    su = "${shadow.su}/bin/su";
    utillinux = util-linux;

    inherit configurationDirectory stateDirectory;

    passthru = {
      tests = {
        inherit (nixosTests)
          containers-imperative
          containers-ip
          containers-tmpfs
          containers-ephemeral
          containers-unified-hierarchy
          ;
      };
    };

    postInstall = ''
      t=$out/share/bash-completion/completions
      mkdir -p $t
      cp ${./botnix-container-completion.sh} $t/botnix-container
    '';
}
