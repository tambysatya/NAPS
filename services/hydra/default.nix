
{flakeRoot, inputs, config, lib, pkgs, infra, path, ... }:
let
    utils = import "${flakeRoot}/lib" {inherit lib inputs;};
    domain = infra.topology.domain;
    hostname = "hydra.${domain}";
in {
config.services.hydra = {
    enable = true;
    listenHost = "0.0.0.0";
    hydraURL = hostname;
    dbi = "dbi:Pg:dbname=hydra;host=postgres.${domain};user=hydra;";
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
    /var/lib/secreast/db-hydra.key.pgpass \
    /var/lib/hydra/pgpass-www

  install -m 0600 -o hydra-queue-runner -g hydra \
    /var/lib/secrets/db-hydra.key.pgpass \
    /var/lib/hydra/pgpass-queue-runner
'';
}
