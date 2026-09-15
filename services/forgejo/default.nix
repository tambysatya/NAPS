{flakeRoot, inputs, config, lib, pkgs, topology, path, vmname, deploy, ... }:
let
    utils = import "${flakeRoot}/lib" {inherit lib inputs;};
    domain = topology.domain;
    hostname = "git.${domain}";
in {
networking.firewall.allowedTCPPorts = lib.optionals (deploy.env.type == "container") [80];
services.forgejo = {
    enable = true;
    database = {
        type = "postgres";
        createDatabase = false;
        host = "postgres.${domain}";
        passwordFile = "/var/lib/secrets/db-forgejo.key";
    };
    settings = {
        database.SSL_MODE = lib.mkForce "verify-full";
        server = {
            DOMAIN= hostname;
            HTTP_ADDR = if deploy.env.type == "container" then "0.0.0.0" else "127.0.0.1"; #listens everywhere if located within a container
            HTTP_PORT = 3000;
            PROTOCOL = "http";
            SSH_PORT = 5022;
            COOKIE_SECURE = false; #TODO ?
            ROOT_URL⁼"https://${hostname}/";
        };

        storage = {
            STORAGE_TYPE = "minio";
            SERVE_DIRECT = false;
            MINIO_ENDPOINT = "s3.${domain}:443";
            MINIO_ACCESS_KEY_ID = builtins.readFile "${path}/.secrets/git/s3-forgejo.id";
            MINIO_BUCKET = "forgejo";
            MINIO_BUCKET_LOOKUP = "auto";
            MINIO_LOCATION = "garage";
            MINIO_USE_SSL = true;
            MINIO_INSECURE_SKIP_VERIFY = false;
            MINIO_CHECKSUM_ALGORITHM = "md5";
        };
    };
    secrets = {
        storage = {
            MINIO_SECRET_ACCESS_KEY = "/var/lib/secrets/s3-forgejo.key";
        };
    };
};
}
