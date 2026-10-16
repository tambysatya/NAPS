{flakeRoot, lib, inputs, ...}:

/* A simple wrapper around haproxy */

let
    types = lib.types // import "${flakeRoot}/lib/types" {inherit lib inputs;};
    utils = import "${flakeRoot}/lib" {inherit lib inputs;}; 
   
    bind = lib.mkOption {
        description = "List of ip addresses to listen on"; 
        type = types.listOf types.str;
        default = [];
        apply = x: if x == [] then "HAProxy: the frontend has no assigned IP addresses" else lib.unique x;
    };
    backend = types.submodule {
        options = {
            inherit (types) ip port;
        };
    };

    tcpProxy = types.submodule {
        options = {
            inherit bind;
            backends = lib.mkOption {
                description = "List of backends";
                type = types.listOf backend;
                default = [];
                apply = x: if x == [] then "HAProxy: no backend assigned" else lib.unique x;
            };
        };
    };

    
in 

{
    options.services.haproxy.http = lib.mkOption {
        description = "HTTPS frontend with HAproxy terminating the TLS connection. Map Hostname [Backend]";
        type = types.submodule {
            options = {
                inherit bind;
                proxy = lib.mkOption {
                    description = "Proxy configuration, indexed by hostname";
                    type = types.attrsOf (types.listOf backend);
                    default = {};
                };
            };
        };
    };
    options.services.haproxy.https = lib.mkOption {
        description = "HTTPS frontend with HAproxy propagating the TLS connection. Map Hostname [Backend]";
        type = types.submodule {
            options = {
                inherit bind;
                proxy = lib.mkOption {
                    description = "Proxy configuration, indexed by hostname";
                    type = types.attrsOf (types.listOf backend);
                    default = {};
                };
            };
        };
    };

    options.services.haproxy.tcp = lib.mkOption {
        description = "TCP Proxy. Map Port Proxy= ([Bind], [Backend])";
        type = types.attrsOf tcpProxy;
        default = {};
    };

}
