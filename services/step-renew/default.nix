{flakeRoot, inputs, lib, ... }:

let customtypes = import ../../lib/types {inherit lib inputs;};
in {
  imports = [
    ./bootstrap.nix # bootstrap step-ca at the first launch
    ./renew.nix
  ];

  options.services.step-renew = {
    enable = lib.mkEnableOption "Renew certificates using Step CA";

    caURL = lib.mkOption {
      type = lib.types.str;
      description = "Step CA URL.";
      example = "https://step.example.com:8443";
    };

    caFingerprint = lib.mkOption {
      type = lib.types.str;
      description = "Step CA fingerprint.";
    };

    stepPath = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/step";
      description = "STEPPATH.";
    };

    certs = lib.mkOption {
      default = {};
      type = lib.types.listOf customtypes.sslCertificate;
    };
  };
}
