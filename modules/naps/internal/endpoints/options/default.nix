{flakeRoot, lib, inputs, config, ...}:

let
    types = import "${flakeRoot}/lib/types" {inherit lib inputs;};

    endpoints = types.submodule {
        options = {
            exposes = lib.mkOption {
                description = "Set of exposed endpoints. hostname:port -> Endpoint";
                type = types.attrsOf types.endpoint;
                default = {};
            };
            reaches = lib.mkOption {
                description = "Set of reached endpoints. hostname:port -> Endpoint";
                type = types.attrsOf types.endpoint;
                default = {};
            };
        };
    };

    /* Removes from reaches the subset of endpoints that are locally exposed for a given type*/
    filterReaches = 
        exposes: reaches:  #both are hostname:port -> Endpoint
        let exposesNames = builtins.attrNames exposes;
        in lib.filterAttrs (name: _: ! builtins.elem name exposesNames) reaches;
    

in {
    options.naps.internal.endpoints.hosts = lib.mkOption {
        description = "Endpoints hosts: EndpointType -> hostname:port -> ServiceID -> ServiceInstance";
        type = types.attrsOf (types.attrsOf (types.attrsOf types.serviceInstance));
        default = {};
    };
    options.naps.internal.endpoints.consumers = lib.mkOption {
        description = "Which services consume each endpoint: EndpointType -> hostname:port -> ServiceID -> ServiceInstance";
        type = types.attrsOf (types.attrsOf (types.attrsOf types.serviceInstance));
        default = {};
    };
    options.naps.internal.endpoints.perEnv = lib.mkOption {
        description = "Endpoints of each environment: Env -> EndpointType -> Endpoints";
        type = types.attrsOf (types.attrsOf endpoints);
        default = {};

        # Endpoints that are exposed are not considered to be reached
        apply = attrs: lib.mapAttrs 
                            (env: eps:
                                lib.mapAttrs 
                                (eptype: {exposes, reaches}: 
                                    {inherit exposes; reaches = filterReaches exposes reaches;} )
                                eps)
                            attrs;
    };
    options.naps.internal.endpoints.perVM.details = lib.mkOption {
        description = "Endpoints of each VM: VM -> Env -> EndpointType -> Endpoints";
        type = types.attrsOf (types.attrsOf (types.attrsOf endpoints));
        default = {};
    };
    options.naps.internal.endpoints.perVM.global = lib.mkOption {
        description = "Endpoints of each VM, where all the environments are aggregated. VM -> EndpointType -> Endpoints";
        type = types.attrsOf (types.attrsOf endpoints);
        default = {};

        # Endpoints that are exposed are not considered to be reached
        apply = attrs: lib.mapAttrs (vmname: epstypes: lib.mapAttrs (_: {exposes, reaches}: {inherit exposes; reaches = filterReaches exposes reaches;}) epstypes ) attrs;
    };
    options.naps.internal.endpoints.perVM.proxy = lib.mkOption {
        description = "Proxy configuration of each VM";
        type = types.attrsOf types.proxy;
        default = {};
    };

}

