{lib, inputs, ...}:
let
    
    network = import ./network.nix {inherit lib inputs;};
    endpoints = import ./endpoints.nix {inherit lib inputs;};
    deployement = import ./deployement.nix {inherit lib inputs;};
    assets = import ./assets.nix {inherit lib inputs;};
    types = lib.types // network // endpoints // deployement // assets;

    /*  For a given VM:
        - to compute the forward proxy:
            + for the frontend: we need to know, for each local environment, which endpoints are reached
            + for the backend: we need to know the set of "serviceInstances" exposing each endpoint (locally and globally) computed once in hosts
        - to compute the reverse:
            + for the frontend proxy: we need to know, for each endpoint that is locally exposed, which environments are reaching it globally and locally (computed once in consumers)
            + for the backend: we need to know the set of "serviceInstances" exposing each endpoint locally

    */
 
    forwardFrontend = lib.mkOption {
        description = "Frontend intermediate representation: LocalEnvironment -> Map EndpointName Endpoint";
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



in {
    inherit proxyIR;
}

