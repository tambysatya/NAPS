{flakeRoot, lib, inputs, config, ...}:

let
    types = import "${flakeRoot}/lib/types" {inherit lib inputs;};

    endpoints = types.submodule {
        options = {
            exposes = lib.mkOption {
                description = "Set of exposed endpoints. EndpointType -> hostname:port -> [Endpoint]";
                type = types.attrsOf (types.attrsOf types.endpoint);
                default = {};
            };
            reaches = lib.mkOption {
                description = "Set of reached endpoints. EndpointType -> hostname:port -> [Endpoint]";
                type = types.attrsOf (types.attrsOf types.endpoint);
                default = {};
            };
        };
    };

    

in {
    options.naps.internal.endpoints.perEnv = lib.mkOption {
        description = "Endpoints of each environment: Env -> Endpoints";
        type = types.attrsOf endpoints;
        default = {};
    };
    options.naps.internal.endpoints.perVM = lib.mkOption {
        description = "Endpoints of each VM: VM -> Env -> Endpoints";
        type = types.attrsOf (types.attrsOf endpoints);
        default = {};
    };
    /*
    options.naps.internal.endpoints.hosts = lib.mkOption {
        description = "Hosts of each endpoint: Type -> Endpoint -> Map InstanceName ServiceInstance";
        type = types.attrsOf (types.attrsOf (types.attrsOf types.serviceInstance));
        default = {};
    };
    */

}

