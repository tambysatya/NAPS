{flakeRoot, lib, inputs, config, ...}:

let
    types = import "${flakeRoot}/lib/types" {inherit lib inputs;};

    endpoints = types.submodule {
        options = {
            exposes = lib.mkOption {
                description = "Set of exposed endpoints. EndpointType -> hostname:port -> Endpoint";
                type = types.attrsOf (types.attrsOf types.endpoint);
                default = {};
            };
            reaches = lib.mkOption {
                description = "Set of reached endpoints. EndpointType -> hostname:port -> Endpoint";
                type = types.attrsOf (types.attrsOf types.endpoint);
                default = {};
            };
        };
    };

    /* Removes from reaches the subset of endpoints that are locally exposed for a given type*/
    filterReaches_ = 
        exposes: reaches:  #both are hostname:port -> Endpoint
        let exposesNames = builtins.attrNames exposes;
        in lib.filterAttrs (name: _: ! builtins.elem name exposesNames) reaches;

    /* Apply this filter for all types */
    filterReaches =
        exposes: reaches: # both are EndpointType -> hostname:port -> EndPoint
        lib.filterAttrs
            (_: attr: attr != {}) # only keep non-empty attrset for clarity
            (lib.zipAttrsWith 
                (name: values:
                    lib.optionalAttrs (builtins.length values == 2) # we only check endpoints types present in both exposes and reaches
                        (filterReaches_ (builtins.elemAt values 0) (builtins.elemAt values 1)))
                [exposes reaches]);

    

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
        description = "Endpoints of each environment: Env -> Endpoints";
        type = types.attrsOf endpoints;
        default = {};

        # Endpoints that are exposed are not considered to be reached
        apply = attrs: lib.mapAttrs (env: {exposes, reaches}: {inherit exposes; reaches = filterReaches exposes reaches;} ) attrs;
    };
    options.naps.internal.endpoints.perVM.details = lib.mkOption {
        description = "Endpoints of each VM: VM -> Env -> Endpoints";
        type = types.attrsOf (types.attrsOf endpoints);
        default = {};
    };
    options.naps.internal.endpoints.perVM.global = lib.mkOption {
        description = "Endpoints of each VM, where all the environments are aggregated. VM -> Endpoints";
        type = types.attrsOf endpoints;
        default = {};

        # Endpoints that are exposed are not considered to be reached
        apply = attrs: lib.mapAttrs (env: {exposes, reaches}: {inherit exposes; reaches = filterReaches exposes reaches;} ) attrs;
    };

}

