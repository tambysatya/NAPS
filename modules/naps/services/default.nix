{flakeRoot, lib, inputs, config,...}:

let
    utils = import "${flakeRoot}/lib" {inherit lib inputs;};


    assetsProcessor = 
        insname: ins: srvuid: allassets:
        let 
            processProvider = 
                provider:
                assetname: asset: 
                {
                    ${assetname} = {inherit asset; recipients = lib.singleton (utils.insEnvUID ins);};
                };
        in lib.mapAttrs (provider: assets: lib.mkMerge (lib.mapAttrsToList (processProvider provider) assets)) allassets;


    endpointsProcessor = 
        insname: ins: srvuid: allendpoints:
        let
            processProtocol =
                protocol: ep:
                let epname = utils.epToString ep;
                in {
                    ${insname}.exposes.${protocol}.${epname} = ep;
                };
        in lib.mkMerge (lib.mapAttrsToList (protocol: endpoints: lib.mkMerge (map (processProtocol protocol) endpoints)) allendpoints);
    provideProcessor = 
        insname: ins: srvuid: provides:
        let
            processProvide =
                linkname: {${insname}.provides = [linkname];};
        in lib.mkMerge (map processProvide provides);
    linksProcessor = 
        insname: ins: srvuid: links:
        let
            endpoints = config.naps.service.${srvuid}.endpoints or {};
            processLink =
                linkname: accesses:
                let mkUID = config.naps.lib.links.${linkname}.accessuid;
                in {
                    ${insname}.consumes.${linkname} = lib.mkMerge (map (access: {${mkUID access} = access;}) accesses);
                };
        in lib.mkMerge (lib.mapAttrsToList processLink links);






    /* Applies a "processor" function on each instance */
    processService =
        processor: # insname: ins: fieldValue -> AttrSet
        fieldName: # fieldName
        srvuid: srv:
        lib.mkMerge (lib.mapAttrsToList (insname: ins: processor insname ins srvuid srv.${fieldName}) srv.instances);
            
in {
   imports = [./options];
   naps = {
        inputs.assets = lib.mkMerge (lib.mapAttrsToList (processService assetsProcessor "assets") config.naps.services);
        inputs.endpoints = lib.mkMerge (lib.mapAttrsToList (processService endpointsProcessor "endpoints") config.naps.services);
        inputs.links = lib.mkMerge [
            (lib.mkMerge (lib.mapAttrsToList (processService provideProcessor "provides") config.naps.services))
            (lib.mkMerge (lib.mapAttrsToList (processService linksProcessor "links") config.naps.services))
        ];
    };
}
