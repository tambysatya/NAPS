{lib, inputs, ...}:

let
    types = lib.types;
    register = import ./register {inherit inputs lib;};
    internal = import ./internal {inherit inputs lib;};
in 

{
    options.registry.services = lib.mkOption {
        internal = true;
        type = types.attrsOf register.service;
        description = "Resources required by the services (generated during phase1)";
        default = {};
    };
    options.registry.internal = lib.mkOption {
        internal = true;
        description = "Internal representation of the napsstructure, with multiple views";
        type = internal.internal;
    };

    /*
    options.registry.vms = lib.mkOption {
        internal = true;
        type = types.attrsOf types.vmConfig;
        default = {};
    };
    */
        
}

