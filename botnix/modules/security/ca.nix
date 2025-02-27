{ config, lib, pkgs, ... }:

with lib;

let

  cfg = config.security.pki;

  cacertPackage = pkgs.cacert.override {
    blacklist = cfg.caCertificateBlacklist;
    extraCertificateFiles = cfg.certificateFiles;
    extraCertificateStrings = cfg.certificates;
  };
  caBundle = "${cacertPackage}/etc/ssl/certs/ca-bundle.crt";

in

{

  options = {
    security.pki.installCACerts = mkEnableOption "Add CA certificates to system" // {
      default = true;
      internal = true;
    };

    security.pki.certificateFiles = mkOption {
      type = types.listOf types.path;
      default = [];
      example = literalExpression ''[ "''${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt" ]'';
      description = lib.mdDoc ''
        A list of files containing trusted root certificates in PEM
        format. These are concatenated to form
        {file}`/etc/ssl/certs/ca-certificates.crt`, which is
        used by many programs that use OpenSSL, such as
        {command}`curl` and {command}`git`.
      '';
    };

    security.pki.certificates = mkOption {
      type = types.listOf types.str;
      default = [];
      example = literalExpression ''
        [ '''
            Botnix.org
            =========
            -----BEGIN CERTIFICATE-----
            MIIGUDCCBTigAwIBAgIDD8KWMA0GCSqGSIb3DQEBBQUAMIGMMQswCQYDVQQGEwJJ
            TDEWMBQGA1UEChMNU3RhcnRDb20gTHRkLjErMCkGA1UECxMiU2VjdXJlIERpZ2l0
            ...
            -----END CERTIFICATE-----
          '''
        ]
      '';
      description = lib.mdDoc ''
        A list of trusted root certificates in PEM format.
      '';
    };

    security.pki.caCertificateBlacklist = mkOption {
      type = types.listOf types.str;
      default = [];
      example = [
        "WoSign" "WoSign China"
        "CA WoSign ECC Root"
        "Certification Authority of WoSign G2"
      ];
      description = lib.mdDoc ''
        A list of blacklisted CA certificate names that won't be imported from
        the Mozilla Trust Store into
        {file}`/etc/ssl/certs/ca-certificates.crt`. Use the
        names from that file.
      '';
    };

  };

  config = mkIf cfg.installCACerts {

    # Botnix canonical location + Debian/Ubuntu/Arch/Gentoo compatibility.
    environment.etc."ssl/certs/ca-certificates.crt".source = caBundle;

    # Old Botnix compatibility.
    environment.etc."ssl/certs/ca-bundle.crt".source = caBundle;

    # CentOS/Fedora compatibility.
    environment.etc."pki/tls/certs/ca-bundle.crt".source = caBundle;

    # P11-Kit trust source.
    environment.etc."ssl/trust-source".source = "${cacertPackage.p11kit}/etc/ssl/trust-source";

  };

}
