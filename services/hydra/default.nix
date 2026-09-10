
{flakeRoot, inputs, config, lib, pkgs, infra, path, ... }:
let
    utils = import "${flakeRoot}/lib" {inherit lib inputs;};
    domain = infra.topology.domain;
    hostname = "hydra.${domain}";
    /* 
    sudo -u hydra env \
          PGPASSFILE=/var/lib/hydra/pgpass \
          HYDRA_DBI='dbi:Pg:dbname=hydra;host=postgres.local.lphi.umontpellier.fr;user=hydra;sslmode=require' \
          hydra-create-user admin --role admin --password-prompt
  */

    init-password-script = pkgs.writeShellScript "init-hydra-password" ''
      set -euo pipefail
      hash="$(
        ${pkgs.coreutils}/bin/cat /var/lib/secrets/hydra-admin-pass.key |
          ${pkgs.libargon2}/bin/argon2 \
            "$(LC_ALL=C ${pkgs.coreutils}/bin/tr -dc '[:alnum:]' < /dev/urandom | ${pkgs.coreutils}/bin/head -c16)" \
            -id -t 3 -k 262144 -p 1 -l 16 -e
      )"
      export PGPASSFILE=/var/lib/hydra/pgpass
      export HYDRA_DBI="${config.services.hydra.dbi}"
      ${config.services.hydra.package}/bin/hydra-create-user admin \
        --password-hash "$hash" \
        --role admin
    '';
in {
config.services.hydra = {
    enable = true;
    listenHost = "0.0.0.0";
    hydraURL = hostname;
    dbi = "dbi:Pg:dbname=hydra;host=postgres.${domain};user=hydra;sslmode=require";
    notificationSender = "hydra@${domain}";
    /*
    extraEnv = {
        PGPASSFILE = lib.mkForce "/var/lib/secrets/db-hydra.key.pgpass";
    };
    */
};
config.systemd.services.hydra-init.preStart = lib.mkAfter ''
  install -m 0600 -o hydra -g hydra \
    /var/lib/secrets/db-hydra.key.pgpass \
    /var/lib/hydra/pgpass

  install -m 0600 -o hydra-www -g hydra \
    /var/lib/secrets/db-hydra.key.pgpass \
    /var/lib/hydra/pgpass-www

  install -m 0600 -o hydra-queue-runner -g hydra \
    /var/lib/secrets/db-hydra.key.pgpass \
    /var/lib/hydra/pgpass-queue-runner
'';
config.systemd.services.hydra-init-passwords = {
    description = "Initializes hydra admin password";
    wantedBy = [ "multi-user.target" ];
    after = [ "hydra-init.service" ];
    requires = [ "hydra-init.service" ];

    serviceConfig = {
      Type = "oneshot";
      User = "hydra";
      ExecStart = init-password-script;
      RemainAfterExit = true;
    };
};
}
