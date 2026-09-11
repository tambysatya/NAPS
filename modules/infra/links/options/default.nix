{flakeRoot, lib, inputs, config, ...}:

let
    utils = import ../lib {inherit inputs lib flakeRoot;};    
    types = import "${flakeRoot}/lib/types" {inherit lib inputs;};
    
    s3link = types.submodule {
        options = {
            env = lib.mkOption {
                description = "Environment of the service requesting this link";
                type = types.deployementEnvironment;
            };
            access = lib.mkOption {
                description = "Access details";
                type = types.s3access;
            };
        };
    };

    dblink = types.submodule {
        options = {
            env = lib.mkOption {
                description = "Environment of the service requesting this link";
                type = types.deployementEnvironment;
            };
            access = lib.mkOption {
                description = "Access details";
                type = types.postgresAccess;
            };


        };
    };
    systemLinks = types.submodule {
        options = {
            s3 = lib.mkOption {
                description = "S3 buckets";
                type = types.listOf s3link;
                default = [];
            };
            postgres = lib.mkOption {
                description = "Databases";
                type = types.listOf dblink;
                default = [];
            };

        };
    };

    #TODO LDAP links
in {

options.infra.links = lib.mkOption {
    description = "Summary of the links in the infrastructure per real virtual machine (containers are excluded)" ;
    type = types.attrsOf systemLinks;

};

}
