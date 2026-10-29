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
    options.naps.internal.endpoints.perEnv = lib.mkOption {
        description = "Endpoints exposed by each environment: Map EnvUID (Map EndpointType (Map hostname:port Endpoint))";
        type = types.attrsOf (types.attrsOf (types.attrsOf types.endpoint));
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
    options.naps.internal.endpoints.outputs.firewall = lib.mkOption {
        description = ''
            Firewall config of each environment
            Map EnvUID (Map Proto (Map Interface [Port]))
        '';
        type = types.attrsOf types.str;
        default = {};
        apply = 
            lib.mapAttrs 
                (name: attr: #env (proto)
                    assert (builtins.hasAttr name config.naps.internal.envs.all) || 
                    throw "endpoints.firewall: unknown env ${name}"; 
                    lib.mapAttrs 
                        (proto: interfaces:  #TODO checks if interface exists
                            lib.mapAttrs (ifname: ports: lib.unique ports) interfaces
                        ) attr);
    };

}

