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
        database.SSL_MODE = lib.mkForce "verify-full";
        server = {
            DOMAIN= hostname;
            HTTP_ADDR = "0.0.0.0";
            HTTP_PORT = 80;
            PROTOCOL = "http";
            SSH_PORT = 5022;
            COOKIE_SECURE = false; #TODO ?
        };

        storage = {
            STORAGE_TYPE = "minio";
            SERVE_DIRECT = false;
            MINIO_ENDPOINT = "https://s3.${domain}:3900";
            MINIO_ACCESS_KEY_ID = builtins.readFile "${path}/.secrets/git/s3-forgejo.id";
            MINIO_BUCKET = "forgejo";
            MINIO_BUCKET_LOOKUP = "auto";
            MINIO_LOCATION = "garage";
            MINIO_USE_SSL = false;
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
