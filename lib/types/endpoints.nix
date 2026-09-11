
/* Exposed endpoints of the service */

{lib,inputs, ...}:
let
    libtypes = lib.types;
    network = import ./network.nix {inherit lib inputs;};
    types = libtypes // network;

in
rec {
    
    httpEndpoint = types.submodule {
        options = {
            inherit (types) hostname port;
            tls = lib.mkOption {
                description = "If set to true, a proxy performing TLS termination will be set up. Use this option if your server does not support TLS natively."; 
                type = types.bool;
                default = false;
            };
            extraConfig = lib.mkOption {
                description = "Extra attrset transfered to the proxy configuration";
                type = types.attrs;
                default = {};
            };
        };
    };
    tcpEndpoint = types.submodule {
        options = {
            inherit (types) hostname port;
            extraConfig = lib.mkOption {
                description = "Extra attrset transfered to the proxy configuration";
                type = types.attrs;
                default = {};
            };
        };
    };

    udpEndpoint = types.submodule {
        options = {
            inherit (types) hostname port;
        };
    };  
    endpoints = types.submodule {
        options = {
            udp = lib.mkOption {
                description = "UDP endpoints.";
                type = types.listOf udpEndpoint; # endpoints are list because the same hostname can lead to multiple ports
                default = [];
            };
            tcp = lib.mkOption {
                description = "TCP endpoints.";
                type = types.listOf tcpEndpoint;
                default = [];
            };
            http = lib.mkOption {
                description = "TCP endpoints.";
                type = types.listOf httpEndpoint;
                default = [];
            };
        };
    };
}
