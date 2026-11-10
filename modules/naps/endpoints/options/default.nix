{flakeRoot, lib, inputs, config, ...}:

let
    utils = import "${flakeRoot}/lib" {inherit lib inputs;};
    types = import "${flakeRoot}/lib/types" {inherit lib inputs;};



    checkEndpoint =
        protocol: epname: ep@{extraArgs,...}:
        let
            argsType = config.naps.endpoints.protocols.${protocol}.extraArgsType;
        in ep // {extraArgs = utils.checkType "modules/naps/endpoints/options/default.nix" argsType extraArgs;};

    checkProtocol =
        protocol: endpoints:
        let 
            protocolExists = builtins.hasAttr protocol config.naps.endpoints.protocols;
        in 
            assert protocolExists || throw "Unknown protocol: ${protocol}";
            lib.mapAttrs (checkEndpoint protocol) endpoints;


    inputs = types.submodule {
        options = {
            exposes = lib.mkOption {
                description = "Endpoints exposed by the environment: Map Protocol (Map hostname:port Endpoint)";
                type = types.attrsOf (types.attrsOf types.endpoint);
                default = {};
                apply = lib.mapAttrs checkProtocol;
                
            };
            reaches = lib.mkOption {
                description = "Endpoints reached by the environment: Map Protocol (Map hostname:port Endpoint)"; 
                type = types.attrsOf (types.attrsOf types.endpoint);
                default = {};
                apply = lib.mapAttrs checkProtocol;
            };
        };
    };

           
      

in {
    imports = [./protocols.nix];
    options.naps.endpoints.inputs = lib.mkOption {
        description = "Endpoints exposed and reached by each environment: Map EnvUID perEnvConf";
        type = types.attrsOf inputs;
    };

    /*
    options.naps.endpoints.all = lib.mkOption {
        description = "Endpoints detail from name: Map EndpointType (Map hostname:port Endpoint)";
        type = types.attrsOf (types.attrsOf types.endpoint);
        default = {};
    };
    options.naps.endpoints.perEnv = lib.mkOption {
        description = "Endpoints exposed by each environment: Map EnvUID perEnvConf";
        type = types.attrsOf perEnvConf;
    };

    options.naps.endpoints.global.hosts = lib.mkOption {
        description = "Endpoints hosts: EndpointType -> hostname:port -> ServiceID -> ServiceInstance";
        type = types.attrsOf (types.attrsOf (types.attrsOf types.serviceInstance));
        default = {};
    };
    options.naps.endpoints.global.consumers = lib.mkOption {
        description = "Which services consume each endpoint: EndpointType -> hostname:port -> ServiceID -> ServiceInstance";
        type = types.attrsOf (types.attrsOf (types.attrsOf types.serviceInstance));
        default = {};
    };
    options.naps.endpoints.ir = lib.mkOption {
        description = "Proxy configuration of each VM: VM -> EndpointType -> ProxyIR";
        type = types.attrsOf (types.attrsOf types.proxyIR);
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
    */

}

