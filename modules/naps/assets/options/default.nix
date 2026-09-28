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
            inputs = lib.mkOption {
                description = "The type of the asset";
                type =  types.submodule {
                    options = {
                        generate = lib.mkOption {
                            description = "Type of the generator inputs"; 
                            type = types.nullOr types.raw;
                        };
                        install = lib.mkOption {
                            description = "Type of the installer inputs"; 
                            type = types.nullOr types.raw;
                        };
                    };
                };
            };
            apply = lib.mkOption {
                description = "Processing functions";
                type = types.submodule {
                    options = {
                        generate = lib.mkOption {
                            description = "A function to generate the asset. Should have type: [String] -> generatorEntry -> [String]. The first argument is an accumulator of all previously outputted scripts, allowing the generator to add its output BEFORE the others (useful e.g. for the CA which should be generated BEFORE the TLS certificates)";
                            type = types.functionTo (types.functionTo (types.listOf types.str));
                        };
                        install = lib.mkOption {
                            description = "A function to install the asset. Should have type: installerEntry -> Script";
                            type = types.functionTo types.str;
                        };
                    };
                };
            };
        };
    };

    assetScripts = types.submodule {
        options = {
            generate = lib.mkOption {
                description = "Asset generation script for the entire infrastructure.";
                type = types.str;
                default = ""; 
            };
            install = lib.mkOption {
                description = "Asset installation script per VM: format is VM => script";
                type = types.attrsOf types.str;
                default = {};
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
                script = lib.mkOption {
                    description = "Actual generations and installation script, per VM. The generator is a single script, the installers are defined per VM";
                    type = assetScripts;
                };

            };
        };
    };

}
