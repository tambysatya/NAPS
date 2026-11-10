{flakeRoot, lib, inputs, config,...}:

let
    utils = import "${flakeRoot}/lib" {inherit lib inputs;};


    assetsProcessor = 
        insname: ins: allassets:
        let 
            processProvider = 
                provider:
                assetname: asset: 
                {
                    ${assetname} = {inherit asset; recipients = lib.singleton (utils.insEnvUID ins);};
                };
        in lib.mapAttrs (provider: assets: lib.mkMerge (lib.mapAttrsToList (processProvider provider) assets)) allassets;

    /* Applies a "processor" function on each instance */
    processService =
        processor: # insname: ins: fieldValue -> AttrSet
        fieldName: # fieldName
        srvuid: srv:
        lib.mkMerge (lib.mapAttrsToList (insname: ins: processor insname ins srv.${fieldName}) srv.instances);
            
in {
   imports = [./options];
   naps = {
        assets.inputs = lib.mkMerge (lib.mapAttrsToList (processService assetsProcessor "assets") config.naps.services);
    };
}
