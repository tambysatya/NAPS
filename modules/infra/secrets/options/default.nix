{flakeRoot, lib, inputs, ...}:
let
    types = lib.types // (import "${flakeRoot}/lib/types" {inherit lib inputs;});
in 

{
    options.infra.secrets = lib.mkOption {
        description = "Summary of the secrets dispatched across the infrastructure. Useful for automatic secret generations.";
        type = types.submodule {
            options = {
                allEnvs = lib.mkOption {
                    description = "List of unique identifiers";
                    type = types.listOf types.deployementEnvironment;
                    default = [];
                };
                allSecrets = lib.mkOption {
                    description = "Summary of the secrets dispatched across the infrastructure. Useful for automatic secret generations.";
                    type = types.listOf types.secret;
                    default = [];
                };
                perVM = lib.mkOption {
                    description = "List of the secrets per virtual machine";
                    type = types.attrsOf (types.listOf types.secret);
                    default = {};
                };
            };
        };
    };

}
