{flakeRoot, lib, inputs, ...}:
let
    types = lib.types // (import "${flakeRoot}/lib/types" {inherit lib inputs;});
    utils = import "${flakeRoot}/lib" {inherit inputs lib;};

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
                recipients = lib.mkOption {
                    description = "Agregation of the recipients of each asset: Map Provider (Map AssetName [EnvUID])";
                    type = types.attrsOf (types.attrsOf (types.listOf types.str));
                    default = {};
                    apply = lib.mapAttrs (_: lib.mapAttrs (_: lib.unique));
                };
                perEnv = lib.mkOption {
                    description = "List of the assets per environment: Map EnvName (Map Provider (Map AssetName Asset))";
                    type = types.attrsOf (types.attrsOf (types.attrsOf types.asset));
                    default = {};
                };
                perVM = lib.mkOption {
                    description = "List of the assets per VM: Map VMName (Map Provider (Map AssetName Asset))";
                    type = types.attrsOf (types.attrsOf (types.attrsOf types.asset));
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
