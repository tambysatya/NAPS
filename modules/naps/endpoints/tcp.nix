{flakeRoot, lib, inputs, config, ...}:

let
    types = import "${flakeRoot}/lib/types" {inherit lib inputs;};
    utils = import "./lib" {inherit flakeRoot lib inputs;};

    displayBackendIP = ep@{hostname, port,...}: i: ins: "server be_tcp_${hostname}_${lib.toString port}_${lib.toString i} ${utils.envIP (utils.serviceEnv ins)}:${lib.toString port} check ${lib.optionalString (i > 1) "backup"}";

    forwardProxy =
        epname: ep@{hostname, port}:
        locally:
        globally:
        let
        in {};
    reverseProxy =
        epname: ep@{hostname, port}:
        locally:
        globally:
        let
        in {};
    generateProxy =
        alleps: # EndpointName -> {endpoint, globally, locally}
        let
        in {};
in {
    naps.endpoints.tcp = {
        inherit generateProxy;
    };
}


