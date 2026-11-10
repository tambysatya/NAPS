{flakeRoot, lib, inputs, config, ...}:
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

    assetsOutputs = types.submodule {
        options = {
            scripts = lib.mkOption {
                description = "Actual generations and installation script, per VM. The generator is a single script, the installers are defined per VM";
                type = assetScripts;
            };
            config = lib.mkOption {
                description = "Extra configuration of each environment: Map EnvUID Config";
                type = types.attrsOf types.config;
                default = {};
            };

        };
    };

    applyMerge =
        type: value:
        if type == null then value else type.merge [] [{inherit value; file = "modules.naps.internal.assets.default";}];
    checkAsset = 
        provider: {generateArgs, installArgs, reload}:
        let 
            inputs = config.naps.assets.${provider}.inputs;
            generateArgs' = applyMerge inputs.generateArgs generateArgs;
            installArgs' = applyMerge inputs.installArgs installArgs;
        in {inherit reload; generateArgs=generateArgs'; installArgs=installArgs';};

    addPath = 
        assetname: asset@{installArgs,...}:
        if builtins.hasAttr "path" installArgs && installArgs.path != null && installArgs.path != ""
            then asset else asset // {installArgs = installArgs // {path = "${utils.paths.secrets/${assetname}}";};};

in 

{
    options.naps.internal.assets = lib.mkOption {
        description = "Assets dispatched across the infrastructure";
        type = types.submodule {
            options = {
                inputs = lib.mkOption {
                    description = ''
                        Inputs of the module. The type of each assets, according to the provider specifications, is checked here.
                        naps.internal.assets :: Map Provider (Map AssetName ShippedAsset = (asset, [recipientsEnvUID]))
                    '';
                    type = types.attrsOf (types.attrsOf types.shippedAsset);
                    default = {};
                    apply = lib.mapAttrs 
                                (provider: 
                                    lib.mapAttrs 
                                        (assetname: shipped@{asset, recipients}: {
                                            inherit recipients;
                                            asset = addPath assetname (checkAsset provider asset);
                                         }));
                };
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
                    description = "List of the assets per VM: Map VMName (Map EnvUID (Map Provider (Map AssetName Asset)))";
                    type = types.attrsOf (types.attrsOf (types.attrsOf (types.attrsOf types.asset)));
                    default = {};
                };
                outputs = lib.mkOption {
                    description = ''
                        Outputs of this modules, containing assets generation and installation script, as well as 
                        the specific configuration of each environment
                    '';
                    type = assetsOutputs;
                };
                
            };
        };
    };

}
