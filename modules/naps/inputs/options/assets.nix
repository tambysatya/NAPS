{flakeRoot, lib, inputs,config,...}:

let
    types = lib.types // (import "${flakeRoot}/lib/types" {inherit lib inputs;});
    utils = import "${flakeRoot}/lib" {inherit inputs lib;};


    checkAsset = 
        provider: assetname: shippedasset@{asset, ...}:
        let  
            inherit (asset) generateArgs installArgs reload;
            inputs = config.naps.lib.assets.${provider}.inputs;
            generateArgs' = utils.checkType "modules/naps/assets/options/default.nix" inputs.generateArgs generateArgs;
            installArgs' = utils.checkType "modules/naps/assets/options/default.nix" inputs.installArgs installArgs;
        in 
           shippedasset // {asset = {inherit reload; generateArgs=generateArgs'; installArgs=installArgs';};};

    checkProvider = 
        provider: allshippedassets:
        let 
            providerExists = builtins.hasAttr provider config.naps.lib.assets;
        in assert providerExists || throw "Unknown asset provider: ${provider}";
           lib.mapAttrs (checkAsset provider) allshippedassets;

in 

{
    options.naps.inputs.assets = lib.mkOption {
        description = ''
            Inputs of the module. The type of each assets, according to the provider specifications, is checked here.
            naps.internal.assets :: Map Provider (Map AssetName ShippedAsset = (asset, [recipientsEnvUID]))
        '';
        type = types.attrsOf (types.attrsOf types.shippedAsset);
        default = {};
        apply = lib.mapAttrs checkProvider;
                        
    };
}
