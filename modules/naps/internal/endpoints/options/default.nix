{flakeRoot, lib, inputs, config, ...}:

let
    utils = import "${flakeRoot}/lib" {inherit lib inputs;};
    types = import "${flakeRoot}/lib/types" {inherit lib inputs;};

           
      

in {
    options.naps.internal.endpoints.all = lib.mkOption {
        description = "Endpoints detail from name: Map EndpointType (Map hostname:port Endpoint)";
        type = types.attrsOf (types.attrsOf types.endpoint);
        default = {};
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
    options.naps.internal.endpoints.proxy = lib.mkOption {
        description = "Proxy configuration of each VM: VM -> EndpointType -> ProxyIR";
        type = types.attrsOf (types.attrsOf types.proxyIR);
        default = {};
    };
    options.naps.internal.endpoints.outputs.proxy = lib.mkOption {
        description = "HAProxy config of each VM";
        type = types.attrsOf types.str;
        default = {};
    };

}

