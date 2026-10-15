
/* Exposed endpoints of the service */

{lib,inputs, ...}:
let
    libtypes = lib.types;
    network = import ./network.nix {inherit lib inputs;};
    types = libtypes // network;

    link = config: lib.mkOption {
        description = "If not null, this endpoint corresponds to a link";
        type = types.nullOr types.str;
        default = null;
        apply = x: if x != null && ! builtins.hasAttr x config.naps.links then throw "${x} is not a valid link." else x;
    };

    proxyExtraConfig = types.submodule {
        options = {
            frontend = lib.mkOption {
                description = "Frontend options";
                type = types.submodule {
                    options = {
                        bind = lib.mkOption {
                            description = "Appened to the bind line";
                            type = types.str;
                            default = "";
                        };
                    };
                };

            };
            backend = lib.mkOption {
                description = "Backend options";
                type = types.attrs;
                default = {};
            };
        };
    };
    
    httpEndpoint = config:  types.submodule {
        options = {
            inherit (types) hostname port;
            link = link config;
            tls = lib.mkOption {
                description = "If set to true, a proxy performing TLS termination will be set up. Use this option if your server does not support TLS natively."; 
                type = types.bool;
                default = false;
            };
            extraConfig = lib.mkOption {
                description = "Extra attrset transfered to the proxy configuration";
                type = proxyExtraConfig;
            };

        };
    };
    tcpEndpoint = config: types.submodule {
        options = {
            inherit (types) hostname port;
            link = link config;
            extraConfig = lib.mkOption {
                description = "Extra attrset transfered to the proxy configuration";
                type = proxyExtraConfig;
            };
        };
    };

    udpEndpoint = config: types.submodule {
        options = {
            link = link config;
            inherit (types) hostname port;
        };
    };  
    endpoints = config: types.submodule {
        options = {
            udp = lib.mkOption {
                description = "UDP endpoints.";
                type = types.listOf (udpEndpoint config); # endpoints are list because the same hostname can lead to multiple ports
                default = [];
            };
            tcp = lib.mkOption {
                description = "TCP endpoints.";
                type = types.listOf (tcpEndpoint config);
                default = [];
            };
            http = lib.mkOption {
                description = "HTTP endpoints.";
                type = types.listOf (httpEndpoint config);
                default = [];
            };
        };
    };



in
rec {
    inherit endpoints;
}
