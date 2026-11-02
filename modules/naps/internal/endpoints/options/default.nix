{flakeRoot, lib, inputs, config, ...}:

let
    utils = import "${flakeRoot}/lib" {inherit lib inputs;};
    types = import "${flakeRoot}/lib/types" {inherit lib inputs;};



    perEnvConf = types.submodule {
        options = {
            exposes = lib.mkOption {
                description = "Endpoints exposed by the environment: Map EndpointType (Map hostname:port Endpoint)";
                type = types.attrsOf (types.attrsOf types.endpoint);
                default = {};
            };
            reaches = lib.mkOption {
                description = "Endpoints reached by the environment: [hostname]";
                type = types.attrsOf (types.attrsOf types.endpoint);
                default = {};
            };
        };
    };
           
      

in {
    options.naps.internal.endpoints.all = lib.mkOption {
        description = "Endpoints detail from name: Map EndpointType (Map hostname:port Endpoint)";
        type = types.attrsOf (types.attrsOf types.endpoint);
        default = {};
    };
    options.naps.internal.endpoints.perEnv = lib.mkOption {
        description = "Endpoints exposed by each environment: Map EnvUID perEnvConf";
        type = types.attrsOf perEnvConf;
    };

    options.naps.internal.endpoints.global.hosts = lib.mkOption {
        description = "Endpoints hosts: EndpointType -> hostname:port -> ServiceID -> ServiceInstance";
        type = types.attrsOf (types.attrsOf (types.attrsOf types.serviceInstance));
        default = {};
    };
    options.naps.internal.endpoints.global.consumers = lib.mkOption {
        description = "Which services consume each endpoint: EndpointType -> hostname:port -> ServiceID -> ServiceInstance";
        type = types.attrsOf (types.attrsOf (types.attrsOf types.serviceInstance));
        default = {};
    };
    options.naps.internal.endpoints.ir = lib.mkOption {
        description = "Proxy configuration of each VM: VM -> EndpointType -> ProxyIR";
        type = types.attrsOf (types.attrsOf types.proxyIR);
        default = {};
    };
    options.naps.internal.endpoints.outputs.proxy = lib.mkOption {
        description = "HAProxy config of each VM";
        type = types.attrsOf types.str;
        default = {};
    };
    options.naps.internal.endpoints.outputs.firewall = lib.mkOption {
        description = ''
            Firewall config of each environment
            Map EnvUID (Map Interface (Map Proto [Ports]))
        '';
        type = types.attrsOf (types.attrsOf (types.attrsOf (types.listOf lib.types.port)));
        default = {};
        apply = lib.mapAttrs (_: lib.mapAttrs (_: lib.mapAttrs (_: lib.unique)));
    };

}

