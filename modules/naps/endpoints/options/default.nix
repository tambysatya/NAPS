{flakeRoot, lib, inputs, config, ...}:

let
    utils = import ../lib {inherit inputs lib flakeRoot;};    
    types = import "${flakeRoot}/lib/types" {inherit lib inputs;};

    proxySection = types.submodule {
        options = {
            description = "A section of the haproxy configuration";
            type = types.listOf types.str;
        };
    };

    
    #maybe not the right name TODO
    endpointProvider = types.submodule {
        options = {
            type = lib.mkOption {
                description = "Type of the endpoint description";
                type = types.raw;
            };
            generateProxy = lib.mkOption {
                description = "Given the set of all the endpoints of this type, generate a proxy configuration. [(Endpoint, [Env])] -> Map ProxySection String";
                type = types.functionTo (types.attrsOf proxySection);
            };
            generateReverseProxy = lib.mkOption {
                description = "Given the set of all the endpoints of this type, generate a reverse proxy configuration. [(Endpoint, [Env])] -> Map ProxySection String";
                type = types.functionTo (types.attrsOf proxySection);
            };
        };
    };

in 
{
    options.naps.endpoints = lib.mkOption {
        description = "All available endpoints types. Map EndpointType Provider";
        type = types.attrsOf endpointProvider;
        default = {};
    };
}
 
