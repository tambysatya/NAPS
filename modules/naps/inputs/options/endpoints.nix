{flakeRoot, lib, inputs, config, ...}:

let
    utils = import "${flakeRoot}/lib" {inherit lib inputs;};
    types = import "${flakeRoot}/lib/types" {inherit lib inputs;};



    checkEndpoint =
        protocol: epname: ep@{extraArgs,...}:
        let
            argsType = config.naps.lib.endpoints.${protocol}.extraArgsType;
        in ep // {extraArgs = utils.checkType "modules/naps/endpoints/options/default.nix" argsType extraArgs;};

    checkProtocol =
        protocol: endpoints:
        let 
            protocolExists = builtins.hasAttr protocol config.naps.lib.endpoints;
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
                apply = lib.mapAttrs checkProtocol; # TODO Also check if each endpoints are exposed (based on config.naps.endpoints.all ?)
            };
        };
    };


in {
    options.naps.inputs.endpoints = lib.mkOption {
        description = "Endpoints exposed by each service: Map InstanceUID {exposes, reaches}";
        type = types.attrsOf inputs;
        default = {};
    };
} 
