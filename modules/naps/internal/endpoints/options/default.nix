{flakeRoot, lib, inputs, config, ...}:

let
    types = import "${flakeRoot}/lib/types" {inherit lib inputs;};

in {
    options.naps.internal.endpoints.perEnv = lib.mkOption {
        description = "Endpoints of each environment: Env -> Endpoints";
        type = types.attrsOf (types.endpoints config);
        default = {};
    };
    options.naps.internal.endpoints.perVM = lib.mkOption {
        description = "Endpoints of each VM: VM -> Env -> Endpoints";
        type = types.attrsOf (types.attrsOf (types.endpoints config));
        default = {};
    };
}

