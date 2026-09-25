{flakeRoot, lib, inputs, ...}:
let
    types = lib.types // (import "${flakeRoot}/lib/types" {inherit lib inputs;});
in 

{
    options.naps.secrets = lib.mkOption {
        description = "Summary of the secrets dispatched across the napsstructure. Useful for automatic secret generations.";
        type = types.submodule {
            options = {
                allEnvs = lib.mkOption {
                    description = "List of unique identifiers";
                    type = types.listOf types.deployementEnvironment;
                    default = [];
                };
                allFiles = lib.mkOption {
                    description = "Summary of the secrets dispatched across the napsstructure. Useful for automatic secret generations.";
                    type = types.attrsOf types.file ;
                    default = {};
                };
                perVM = lib.mkOption {
                    description = "List of the secrets per virtual machine";
                    type = types.attrsOf (types.attrsOf types.file);
                    default = {};
                };
            };
        };
    };

}
