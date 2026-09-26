{flakeRoot, lib, inputs, ...}:
let
    types = lib.types // (import "${flakeRoot}/lib/types" {inherit lib inputs;});

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


    providerEntry = types.submodule {
        options = {
            assetType = lib.mkOption {
                description = "The type of the asset";
                type =  types.submodule {
                    options = {
                        generateArgs = lib.mkOption {
                            description = "Type of the generator inputs"; 
                            type = types.submodule;
                        };
                        installArgs = lib.mkOption {
                            description = "Type of the installer inputs"; 
                            type = types.submodule;
                        };
                    };
                };
            };
            generate = lib.mkOption {
                description = "A function to generate the asset. Should have type: targetPath -> generatorEntry -> Script";
            };
            install = lib.mkOption {
                description = "A function to install the asset. Should have type: installerEntry -> Script";
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
                    type = types.attrsOf (types.attrsOf (types.attrs));
                    default = {};
                };
                providers = lib.mkOption {
                    description = "Provider functions library";
                    type = types.attrsOf providerEntry;
                    default = {};
                };

            };
        };
    };

}
