
{flakeRoot, inputs, config, lib, pkgs, ... }:

let
  vars = import "${flakeRoot}/lib/vars.nix" {inherit lib inputs;};
  cfg = config.services.step-renew;

in
{
  config = lib.mkIf cfg.enable {

    systemd.services.step-bootstrap = {

      description = "Bootstrap Step CA";

      wantedBy = [ "multi-user.target" ];

      before = [ "step-renew.service" ] ++ lib.concatLists (map (builtins.getAttr "reload") cfg.certs);
      requiredBy = [ "step-renew.service" ] ++ lib.concatLists (map (builtins.getAttr "reload") cfg.certs);
      #depends on step-ca if installed locally
      after = ["network-online.target"] ++ lib.optional config.services.step-ca.enable "step-ca.service";
      requires = ["network-online.target"] ++ lib.optional config.services.step-ca.enable "step-ca.service";

      serviceConfig = {
        Type = "oneshot";
        StateDirectory = "step";
        Restart = "on-failure";
        RestartSec = "30s";
      };

      environment = {
        STEPPATH = cfg.stepPath;
      };

      script = ''
        set -euo pipefail

        if [ ! -f "$STEPPATH/config/defaults.json" ]; then
          echo "Bootstrapping Step"

          until ${pkgs.step-cli}/bin/step ca bootstrap \
		    --ca-url ${lib.escapeShellArg cfg.caURL}:8443 \
		    --fingerprint ${lib.escapeShellArg cfg.caFingerprint}
          do
            echo "Remote CA not available, retrying in 30s"
            sleep 30
          done
          chmod go+rx ${cfg.stepPath}/certs
          chmod go+r ${cfg.stepPath}/certs/root_ca.crt

        fi
      '';

    };

  };
}
