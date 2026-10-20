{lib, inputs, ...}:
let
    
    network = import ./network.nix {inherit lib inputs;};
    types = lib.types // network;


    firewallConfig = types.submodule {
        options = {
            interfaces = lib.mkOption {
                description = "On which interface the firewall should be openned. all = all the interfaces";
                type = types.either (types.enum ["all"]) (types.listOf types.str);
            };
            inherit (types) port;
        };
    };
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
                        default = "";
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
            firewall = lib.mkOption {
                description = "Firewall configuration for this frontend";
                type = firewallConfig;
            };
            extraConfig = lib.mkOption {
                description = "Extra config appened in the section";
                type = types.listOf types.str;
                default = [];
            };
        };
    };

    backend = types.submodule {
        options = {
            mode = lib.mkOption {
                description = "Backend mode";
                type = types.enum ["tcp" "http"];
            };
            config = lib.mkOption {
                description = "Remaining of the config lines of the section";
                type = types.listOf types.str;
                default = [];
            };
        };
    };
 
    haproxyConfig = types.submodule {
        options = {
            frontends = lib.mkOption {
                description = "Description of the frontends";
                type = types.attrsOf frontend;
                default = {};
            };
            backends = lib.mkOption {
                description = "Description of the backends";
                type = types.attrsOf backend;
                default = {};
            };
        };
    };
    proxy = types.submodule {
        options = {
            extraArgsType = lib.mkOption {
                description = "An endpoint contains {hostname, port, extraArgs}. This specifies the type of the user-defined extraArgs";
                type = types.nullOr types.raw;
                default = null;
            };
            generateProxy = lib.mkOption {
                description = "Given the set of all the endpoints of this type, generate a proxy configuration for this type of endpoint: perVM: vmname -> hosts -> consumers -> exposes -> reaches -> haproxyConfig";
                type = types.functionTo (types.functionTo (types.functionTo (types.functionTo (types.functionTo haproxyConfig))));
            };
        };
    };

in {
    inherit proxy;
}

