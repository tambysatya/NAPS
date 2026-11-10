{flakeRoot, lib, inputs, config,...}:

let
    utils = import "${flakeRoot}/lib" {inherit lib inputs;};


    processAssets = 
        insname: ins: allassets:
        let 
            processProvider = 
                provider:
                assetname: asset: 
                {
                    ${assetname} = {inherit asset; recipients = lib.singleton (utils.insEnvUID ins);};
                };
        in lib.mapAttrs (provider: assets: lib.mkMerge (lib.mapAttrsToList (processProvider provider) assets)) allassets;

    processInstance =
        srvuid: srv@{assets, provides, links, endpoints,...}: 
        insname: ins:
        lib.mkMerge [
            {assets.inputs = processAssets insname ins assets;}
        ];



    processService =
        srvuid: srv@{instances, assets, provides, links, endpoints, ...}:
        lib.mkMerge (lib.mapAttrsToList (processInstance srvuid srv) instances);
            
in {
   imports = [./options];
   naps.internal = lib.mkMerge (lib.mapAttrsToList processService config.naps.services);
}
