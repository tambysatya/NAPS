{flakeRoot, lib, inputs, config, ...}:

let
    utils = import ../lib {inherit inputs lib flakeRoot;};    
    types = import "${flakeRoot}/lib/types" {inherit lib inputs;};
       
in 
{
    options.naps.endpoints = lib.mkOption {
        description = "All available endpoints types. Map EndpointType Provider";
        type = types.attrsOf types.proxy;
        default = {};
    };
}
 
