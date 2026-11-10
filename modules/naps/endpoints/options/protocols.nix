{flakeRoot, lib, inputs, config, ...}:

let
    utils = import ../lib {inherit inputs lib flakeRoot;};    
    types = import "${flakeRoot}/lib/types" {inherit lib inputs;};

    endpointType = types.submodule {
        options = {
            extraArgsType = lib.mkOption {
                description = "An endpoint contains {hostname, port, extraArgs}. This specifies the type of the user-defined extraArgs";
                type = types.nullOr types.raw;
                default = null;
            };

            generateAssets = lib.mkOption {
                description = ''
                    Function providing a list endpointsAsset, i.e. assets decorated 
                    with the list of recipients (environment name), given the endpoint
                    and the environment of the service deploying the endpoint.
                    Endpoint -> DeployementEnv -> Map ProviderType (Map AssetName ShippedAsset)
                '';
                type = types.functionTo (types.functionTo (types.attrsOf (types.attrsOf types.shippedAsset)));
                default = ep: env: {};
            };
            generateProxy = lib.mkOption {
                description = ''
                    Given the intermediate representation of the VM proxy and
                    the set of all the hosts and consumers of each endpoint
                    over the infrastructure, generate the haproxy configuration.
                    Type: VMEnv -> Hosts -> Consumers -> ProxyIR -> HAProxy configuration
                '';
                type = types.functionTo (types.functionTo (types.functionTo (types.functionTo types.str)));
            };
            generateFirewall = lib.mkOption { # TODO block also connections to the outside ?
                description = ''
                    Given the set of exposed endpoints, generates the firewall configuration
                    of the VM /containers. 
                    Type: VMEnv -> ProxyIR -> Map EnvUID (Map Interface (Map Proto [Port]))
                ''; #TODO : firewall for containers ?
                type = types.functionTo (types.functionTo (types.attrsOf (types.attrsOf (types.attrsOf (types.listOf lib.types.port)))));
                default = env: ir: {};
            };
        };
    };
       
in 
{
    options.naps.endpoints.protocols = lib.mkOption {
        description = "All available endpoints types. Map EndpointType Provider";
        type = types.attrsOf endpointType;
        default = {};
    };
}
 
