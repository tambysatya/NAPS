{flakeRoot, lib, inputs, config, ...}:

let
    utils = import "${flakeRoot}/lib" {inherit lib inputs;};
    types = import "${flakeRoot}/lib/types" {inherit lib inputs;};

          
      

in {


    options.naps.endpoints.all = lib.mkOption {
        description = "Endpoints detail from name: Map Protocol (Map hostname:port Endpoint)";
        type = types.attrsOf (types.attrsOf types.endpoint);
        default = {};
    };

    options.naps.endpoints.hosts = lib.mkOption {
        description = "Endpoints hosts: Protocol -> hostname:port -> ServiceID -> ServiceInstance";
        type = types.attrsOf (types.attrsOf (types.attrsOf types.serviceInstance));
        default = {};
    };
    options.naps.endpoints.perVM = lib.mkOption {
        description = "Exposed endpoints perVM (IR of the reverse-proxy): Map VM (Map Protocol (Map Endpoint (Map InstanceUID ServiceInstance)))";
        type = types.attrsOf (types.attrsOf (types.attrsOf (types.attrsOf types.serviceInstance)));
        default = {};
    };
    options.naps.endpoints.outputs.proxy = lib.mkOption {
        description = "HAProxy config of each VM";
        type = types.attrsOf types.str;
        default = {};
    };
    options.naps.endpoints.outputs.firewall = lib.mkOption {
        description = ''
            Firewall config of each environment
            Map EnvUID (Map Interface (Map Proto [Ports]))
        '';
        type = types.attrsOf (types.attrsOf (types.attrsOf (types.listOf lib.types.port)));
        default = {};
        apply = lib.mapAttrs (_: lib.mapAttrs (_: lib.mapAttrs (_: lib.unique)));
    };

}

