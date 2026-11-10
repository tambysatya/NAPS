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


    addPath = 
        assetname: asset@{installArgs,...}:
        if builtins.hasAttr "path" installArgs && installArgs.path != null && installArgs.path != ""
            then asset else asset // {installArgs = installArgs // {path = "${utils.paths.secrets/${assetname}}";};};


    ir = types.submodule {
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
                description = "List of the assets per VM: Map VMName (Map EnvUID (Map Provider (Map AssetName Asset)))";
                type = types.attrsOf (types.attrsOf (types.attrsOf (types.attrsOf types.asset)));
                default = {};
            };
        };
    };

    checkAsset = 
        provider: assetname: shippedasset@{asset, ...}:
        let  
            inherit (asset) generateArgs installArgs reload;
            inputs = config.naps.assets.providers.${provider}.inputs;
            generateArgs' = utils.checkType "modules/naps/assets/options/default.nix" inputs.generateArgs generateArgs;
            installArgs' = utils.checkType "modules/naps/assets/options/default.nix" inputs.installArgs installArgs;
        in 
           shippedasset // {asset = {inherit reload; generateArgs=generateArgs'; installArgs=installArgs';};};

    checkProvider = 
        provider: allshippedassets:
        let 
            providerExists = builtins.hasAttr provider config.naps.assets.providers;
        in assert providerExists || throw "Unknown asset provider: ${provider}";
           lib.mapAttrs (checkAsset provider) allshippedassets;
in 

{
    imports = [./providers.nix];
    options.naps.assets = lib.mkOption {
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
                    apply = lib.mapAttrs checkProvider;
                                    
                };

                ir = lib.mkOption {
                    description = "Intermediate representation";
                    type = ir;
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
