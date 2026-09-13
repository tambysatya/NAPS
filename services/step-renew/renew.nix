
{flakeRoot, inputs, config, lib, pkgs, ... }:

let

  vars = import "${flakeRoot}/lib/vars.nix" {inherit lib inputs;};
  cfg = config.services.step-renew;

  certEntries =
    map
      ({hostname, owner, reload,...}:
      ''
        echo "Renewing ${hostname}"

        CRT_PATH=${vars.ssl_crt_path hostname}
        KEY_PATH=${vars.ssl_key_path hostname}

        old_hash=$(${pkgs.coreutils}/bin/sha256sum "$CRT_PATH" | cut -d' ' -f1)

        ${pkgs.step-cli}/bin/step ca renew \
          "$CRT_PATH" \
          "$KEY_PATH" \
          --force

        ${if owner == "haproxy" then 
            ''cat "$CRT_PATH" "$KEY_PATH" > ${vars.pemdir}/${hostname}.pem''
          else ""}

        new_hash=$(${pkgs.coreutils}/bin/sha256sum "$CRT_PATH" | cut -d' ' -f1)

        if [ "$old_hash" != "$new_hash" ]; then
          echo "${hostname} changed"

          ${lib.concatMapStringsSep "\n"
            (service:
              "${pkgs.systemd}/bin/systemctl reload-or-restart ${service}"
            )
            reload}
        fi
      '')
      cfg.certs;

in
{

  config = lib.mkIf cfg.enable {

    environment.systemPackages = [pkgs.step-cli];
    systemd.services.step-renew = {

      description = "Renew Step certificates";

      # depends of step-ca if the service is installed locally
      after = [ "step-bootstrap.service" ] 
	      ++ lib.optional config.services.step-ca.enable "step-ca.service";
      requires = [ "step-bootstrap.service" ]
	      ++ lib.optional config.services.step-ca.enable "step-ca.service";

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

        ${lib.concatStringsSep "\n" certEntries}
      '';

    };

    systemd.timers.step-renew = {

      wantedBy = [ "timers.target" ];

      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
      };

    };

  };

}
