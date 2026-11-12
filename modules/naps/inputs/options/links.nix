{flakeRoot, lib, inputs, config,...}:

let
    types = import "${flakeRoot}/lib/types" {inherit lib inputs;};
in {
    options.naps.inputs.links.providers = lib.mkOption {
        description = "Instances providing a link. Map LinkName (Map InstanceUID Instance)";
        type = types.attrsOf (types.attrsOf types.serviceInstance);
        default = {};
    };
    options.naps.inputs.links.consumers = lib.mkOption {
        description = "Instances consuming a link. Map LinkName (Map InstanceUID (Map AccessName Access))";
        type = types.attrsOf (types.attrsOf (types.attrsOf types.anything));
        default = {};
    };
}


