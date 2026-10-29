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
        description = "Frontend intermediate representation: Map LocalEnvironment (Map EndpointName Endpoint)";
        type = types.attrsOf (types.attrsOf types.endpoint);
        default = {};
    };
    reverseBackend = lib.mkOption {
        description = "Backend intermediate representation: Map LocallyExposedEndpoint (Map InstanceName serviceInstances)";
        type = types.attrsOf (types.attrsOf types.serviceInstance);
        default = {};
    };

    proxyIR = types.submodule {
        options = {
            forward = forwardFrontend;
            reverse = reverseBackend;
        };
    };


    firewallConfig = types.attrsOf (types.attrsOf (types.listOf lib.type.port)); # Map Proto (Map Interface [Port])


in {
    inherit proxyIR;
}

