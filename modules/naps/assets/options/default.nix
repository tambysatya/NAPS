{flakeRoot, lib, inputs, ...}:
let
    types = lib.types // (import "${flakeRoot}/lib/types" {inherit lib inputs;});

    installerEntry = types.submodule {
        options = {
            args = lib.mkOption {
                description = "Extra Args for the installer";
                type = types.attrs;
            };
            owner = lib.mkOption {
                description = "Owner of the asset";
                type = types.str;
            };
            group = lib.mkOption {
                description = "Group of the asset. If null, the installer will chose the default value for this type of asset (often a group having the same name as the owner)";
                type = types.nullOr types.str;
            };
            mode = lib.mkOption {
                description = "Permissions of the asset. If null, the installer will chose the default value for this type of asset.";
                type = types.nullOr types.str;
            };
            path = lib.mkOption {
                description = "Installation path. If null, the installer will chose the default value for this type of asset.";
                type = types.nullOr types.str;
            };
        };
    };
    generatorEntry = types.submodule {
        options = {
            args = lib.mkOption {
                description = "Extra args for the generator";
                type = types.attrs;
            };
            recipients = lib.mkOption {
                description = "List of environment to ship the asset";
                type = types.listOf types.deployementEnvironment;
                default = [];
            };
            
        };
    };




in 

{
    options.naps.assets = lib.mkOption {
        description = "Assets dispatched across the infrastructure";
        type = types.submodule {
            options = {
                perEnv = lib.mkOption {
                    description = "List of the assets per environment";
                    type = types.attrsOf (types.attrsOf types.asset);
                    default = {};
                };
                generator = lib.mkOption {
                    description = "Intermediate Representation of the assets generation script. Format is: Provider -> name -> generatorArgs ";
                    type = types.attrsOf (types.attrsOf generatorEntry);
                    default = {};
                };
                installer = lib.mkOption {
                    description = "Intermediate Representation of the assets installation script. Format is: Env -> Provider -> name -> args";
                    type = types.attrsOf (types.attrsOf (types.attrsOf installerEntry));
                    default = {};
                };

            };
        };
    };

}
