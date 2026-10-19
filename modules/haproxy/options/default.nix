{flakeRoot, lib, inputs, ...}:

/* A simple wrapper around haproxy */

let
    types = lib.types // import "${flakeRoot}/lib/types" {inherit lib inputs;};
    utils = import "${flakeRoot}/lib" {inherit lib inputs;}; 
   
    frontend = types.submodule {
        options = {
            bind = types.submodules {
                options = {
                    listen = lib.mkOption {
                        description = "List of IP addresses to listen on";
                        type = types.listOf types.str;
                    };
                    extraArgs = lib.mkOption {
                        description = "Extra args appened to the bind line";
                        type = types.str;
                    };
                };
            };
            mode = lib.mkOption {
                description = "Frontend mode";
                type = types.enum ["tcp" "http"];
            };
            backend = lib.mkOption {
                description = "Backend section";
                type = types.str;
                example = "default_backend be_postgres.local.fr";
            };
            extraConfig = lib.mkOption {
                description = "Extra config appened in the section";
                type = types.listOf types.str;
                default = []:
            };
        };
    };

    backend = types.submodule {
        options = {
            mode = lib.mkOption {
                description = "Frontend mode";
                type = types.enum ["tcp" "http"];
            };
            config = lib.mkOption {
                description = "Remaining of the config lines of the section";
                type = types.listOf types.str;
                default = [];
            };
        };
    };
   
in 

{
    options.services.haproxy.frontends = lib.mkOption {
        description = "(Partially) structured configuration of HAProxy frontends";
        type = types.attrsOf frontend;
        default = {};
    };
    options.services.haproxy.backends = lib.mkOption {
        description = "(Partially) structured configuration of HAProxy backends";
        type = types.attrsOf backends;
        default = {};
    };
}
