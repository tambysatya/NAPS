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


    endpointsProcessor = 
        insname: ins: allendpoints:
        let
            processProtocol =
                protocol: ep:
                let epname = utils.epToString ep;
                in {
                    ${utils.insEnvUID ins}.exposes.${protocol}.${epname} = ep;
                };
        in lib.mkMerge (lib.mapAttrsToList (protocol: endpoints: lib.mkMerge (map (processProtocol protocol) endpoints)) allendpoints);


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
        endpoints.inputs = lib.mkMerge (lib.mapAttrsToList (processService endpointsProcessor "endpoints") config.naps.services);
    };
}
