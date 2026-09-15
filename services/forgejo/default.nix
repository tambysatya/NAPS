{flakeRoot, inputs, config, lib, pkgs, topology, path, ... }:
let
    utils = import "${flakeRoot}/lib" {inherit lib inputs;};
    domain = topology.domain;
    hostname = "git.${domain}";
in {
services.forgejo = {
    enable = true;
    database = {
        type = "postgres";
        createDatabase = false;
        host = "postgres.${domain}";
        passwordFile = "/var/lib/secrets/db-forgejo.key";
    };
    settings = {
        server = {
            DOMAIN= hostname;
            HTTP_ADDR = "0.0.0.0";
            HTTP_PORT = 80;
            PROTOCOL = "http";
            SSH_PORT = 5022;
            COOKIE_SECURE = false; #TODO ?
        };
    };
    secrets = {

    };
};
}
