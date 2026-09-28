{flakeRoot, lib, inputs, ...}:
let
    types = lib.types // (import "${flakeRoot}/lib/types" {inherit lib inputs;});
    utils = import "${flakeRoot}/lib" {inherit inputs lib;};

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

    installerEntry = types.submodule {
        options = {
            generateArgs = lib.mkOption {
                description = "Args that have been passed to the generator";
                type = types.attrs;
            };
            installArgs = lib.mkOption {
                description = "Installer args";
                type = types.attrs;
                default = [];
            };
            
        };
    };


    providerEntry = types.submodule {
        options = {
            generate = lib.mkOption {
                description = "A function to generate the asset. Should have type: [String] -> assetname -> generatorEntry -> [String]. The first argument is an accumulator of all previously outputted scripts, allowing the generator to add its output BEFORE the others (useful e.g. for the CA which should be generated BEFORE the TLS certificates)";
                type = types.functionTo (types.functionTo (types.functionTo (types.listOf types.str)));
            };
            install = lib.mkOption {
                description = "A function to install the asset. Should have type: assetname -> installerEntry -> Script";
                type = types.functionTo (types.functionTo types.str);
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
                    apply =
                        envassets: 
                        lib.mapAttrs 
                            (envname: assets:
                                lib.mapAttrs 
                                    (assetname: asset@{installArgs, ...}:  #sets the default value of path
                                        let installArgs' = if builtins.hasAttr "path" installArgs 
                                                           then installArgs
                                                           else installArgs // {path = "${utils.paths.secrets}/${assetname}";};
                                        in asset // {installArgs = installArgs';})
                                    assets)
                           envassets;
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
                providers = lib.mkOption {
                    description = "Provider functions library";
                    type = types.attrsOf providerEntry;
                    default = {};
                };
                scripts = lib.mkOption {
                    description = "Actual generations and installation script, per VM. The generator is a single script, the installers are defined per VM";
                    type = assetScripts;
                };

            };
        };
    };

}
