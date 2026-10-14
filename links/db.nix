{flakeRoot, lib, inputs, config, pkgs, ...}:

let
    utils = import "${flakeRoot}/lib" {inherit lib inputs;};
    types = lib.types // import "${flakeRoot}/lib/types" {inherit lib inputs;};
    access = types.submodule {
        options = {
            database = lib.mkOption {
                description = "Database name";
                type = types.str;
            };
            inherit (types) owner reload;
        };
    };
in {

naps.links.postgres = {
    inherit access;
    assets = access: {
        "${utils.db_key access}" = {
            provider = "password";
            generateArgs = {opensslSize = 64; opensslType = "base64";};
            installArgs = {inherit (access) owner; group="postgres"; mode = "440";};
            inherit (access) reload;
        };
    };
    match = srvuid: srvuid == "postgres";
    waitLinkUp =  
        ''
        until ${pkgs.postgresql}/bin/pg_isready -h postgres.${config.naps.topology.domain} -p 5432; do
            sleep 1
        done
        echo "Connected to postgres"
        '';
};
}

