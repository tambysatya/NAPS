{flakeRoot, lib, inputs, config, ...}:

let
    types = import "${flakeRoot}/lib/types" {inherit lib inputs;};
    utils = import "${flakeRoot}/lib" {inherit lib inputs;};

    generateProxy = 
    vmname: hosts: consumers: exposes: reaches:
    let
    in {
        frontends = {};
        backends = {};
    };
in 
{
    naps.endpoints.http = {inherit generateProxy;};
    naps.endpoints.https = {inherit generateProxy;};
}


