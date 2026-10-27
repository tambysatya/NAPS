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
            inherit (types) reload;
            
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
    options.naps.internal.assets = lib.mkOption {
        description = "Assets dispatched across the infrastructure";
        type = types.submodule {
            options = {
                all = lib.mkOption {
                    description = "All assets, sorted by Provider: Map Provider (Map AssetName Asset)";
                    type = types.attrsOf (types.attrsOf types.asset);
                    default = {};
                };
                perEnv = lib.mkOption {
                    description = "List of the assets per environment: Map EnvName (Map Provider (Map AssetName Asset))";
                    type = types.attrsOf (types.attrsOf (types.attrsOf types.asset));
                    default = {};
                    /*
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
                    */
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
                scripts = lib.mkOption {
                    description = "Actual generations and installation script, per VM. The generator is a single script, the installers are defined per VM";
                    type = assetScripts;
                };

            };
        };
    };

}
