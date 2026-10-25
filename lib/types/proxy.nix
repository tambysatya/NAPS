{lib, inputs, ...}:
let
    
    network = import ./network.nix {inherit lib inputs;};
    endpoints = import ./endpoints.nix {inherit lib inputs;};
    deployement = import ./deployement.nix {inherit lib inputs;};
    types = lib.types // network // endpoints // deployement;

    /*  For a given VM:
        - to compute the forward proxy:
            + for the frontend: we need to know, for each local environment, which endpoints are reached
            + for the backend: we need to know the set of "serviceInstances" exposing each endpoint (locally and globally) computed once in hosts
        - to compute the reverse:
            + for the frontend proxy: we need to know, for each endpoint that is locally exposed, which environments are reaching it globally and locally (computed once in consumers)
            + for the backend: we need to know the set of "serviceInstances" exposing each endpoint locally

    */
 
    forwardFrontend = lib.mkOption {
        description = "Frontend intermediate representation: LocalEnvironment -> (EndpointName -> Endpoint)";
        type = types.attrsOf (types.attrsOf types.endpoint);
        default = {};
    };
    reverseBackend = lib.mkOption {
        description = "Backend intermediate representation: LocallyExposedEndpoint -> local serviceInstances";
        type = types.attrsOf (types.attrsOf types.serviceInstance);
        default = {};
    };

    proxyIR = types.submodule {
        options = {
            forward = forwardFrontend;
            reverse = reverseBackend;
        };
    };

 

    firewallConfig = types.submodule {
        options = {
            interfaces = lib.mkOption {
                description = "On which interface the firewall should be openned. all = all the interfaces";
                type = types.either (types.enum ["all"]) (types.listOf types.str);
            };
            proto = lib.mkOption {
                description = "Allowed protocol";
                type = types.listOf (types.enum ["tcp" "udp"]);
                apply = lib.unique;
                default = [];
            };
        };
    };

    haproxyConfig = types.submodule {
        options = {
            config = lib.mkOption {
                description = "HAProxy configuration file";
                type = types.listOf types.str;
                default = [];
            };
            firewall = lib.mkOption {
                description = "Firewall configuration: Port -> firewallConfig";
                type = types.attrsOf firewallConfig;
                default = {};
            };
        };
    };
    proxy = types.submodule {
        options = {
            extraArgsType = lib.mkOption {
                description = "An endpoint contains {hostname, port, extraArgs}. This specifies the type of the user-defined extraArgs";
                type = types.nullOr types.raw;
                default = null;
            };
            generateProxy = lib.mkOption {
                description = ''
                    Given the intermediate representation of the VM proxy and
                    the set of all the hosts and consumers of each endpoint
                    over the infrastructure, generate the haproxy configuration.
                    Type: Hosts -> Consumers -> ProxyIR -> haproxyConfig
                '';
                type = types.functionTo (types.functionTo (types.functionTo haproxyConfig));
            };
        };
    };

in {
    inherit proxyIR;
    inherit proxy haproxyConfig;
}

