{flakeRoot, lib, inputs, ...}:
let
    types = lib.types // (import "${flakeRoot}/lib/types" {inherit lib inputs;});
in 

{
    options.naps.secrets = lib.mkOption {
        description = "Assets dispatched across the infrastructure";
        type = types.submodule {
            options = {
                allAssets = lib.mkOption {
                    description = "Summary of the assets dispatched across the napsstructure. Useful for automatic secret generations.";
                    type = types.attrsOf types.assets;
                    default = {};
                };
                perEnv = lib.mkOption {
                    description = "List of the assets per environment";
                    type = types.attrsOf (types.attrsOf types.assets);
                    default = {};
                };
            };
        };
    };

}
