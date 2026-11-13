{flakeRoot, lib, inputs, config, ...}:

let
    utils = import "${flakeRoot}/lib" {inherit lib inputs;};
    types = import "${flakeRoot}/lib/types" {inherit lib inputs;};

    
    endpointIR = types.submodule {
        options = {
            endpoint = lib.mkOption {
                description = "Endpoint description";
                type = types.endpoint;
            };
            hosts = lib.mkOption {
                description = "(Local) Hosts exposing or reaching the endpoint: Map ServiceID ServiceInstance";
                type = types.attrsOf types.serviceInstance;
                default = {};
            };
        };
    };

    vmIR = types.submodule {
        options = {
            exposes = lib.mkOption {
                description = "Exposed endpoints: Map EndpointName EndpointIR = {endpoint, hosts}";
                type = types.attrsOf endpointIR;
                default = {};
            };
            reaches = lib.mkOption {
                description = "Reached endpoints: Map EndpointName EndpointIR = {endpoint, hosts}";
                type = types.attrsOf endpointIR;
                default = {};
            };
        };
    };


       
      

in {


    options.naps.endpoints.all = lib.mkOption {
        description = "Endpoints detail from name: Map Protocol (Map hostname:port Endpoint)";
        type = types.attrsOf (types.attrsOf types.endpoint);
        default = {};
    };

    options.naps.endpoints.providers = lib.mkOption {
        description = "Endpoints providers: Map Protocol (Map hostname:port {endpoint, hosts})";
        type = types.attrsOf (types.attrsOf endpointIR);
        default = {};
    };
    options.naps.endpoints.consumers= lib.mkOption {
        description = "Endpoints consumers: Map Protocol (Map hostname:port {endpoint, hosts})";
        type = types.attrsOf (types.attrsOf endpointIR);
        default = {};
    };
    options.naps.endpoints.perVM = lib.mkOption {
        description = '' 
            Exposed endpoints per environment (IR of the reverse-proxy/forward proxy):
            Map EnvUID (Map Protocol {exposes, reaches}) with exposes, reaches: Map EndpointName {endpoint, hosts}
            Note that hosts are restricted to the LOCAL envs (e.g. native + containers hosted on the VM)
        '';
        type = types.attrsOf (types.attrsOf vmIR); # Map VMName (Map Protocol IR)
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

