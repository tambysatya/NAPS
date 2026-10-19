{flakeRoot, lib, inputs, config, path, pkgs,...}:
let
    utils = import "${flakeRoot}/lib" {inherit lib inputs;};

    processService = 
        srvname: {deployements, provides, endpoints, links,...}:
        let 
           
           generateLinksEndpoints =
                insname: env: linktype: 
                let
                    linkendpoints = config.naps.links.${linktype}.endpoints; # EndpointType -> [Endpoint]
                in
                    lib.mapAttrsToList 
                        (eptype: eps:
                            {
                                ${eptype} = lib.mkMerge (map (ep: {${utils.epToString ep} = ep;}) eps);
                            }) 
                        linkendpoints;

           processDeployement =
            insname: env:
            let
                reaches = lib.mkMerge
                            (lib.concatMap
                                (generateLinksEndpoints insname env)
                                (builtins.attrNames links));
                exposes = lib.mkMerge  [
                              # endpoints associated with the link of the service
                              (lib.mkMerge (lib.concatMap (generateLinksEndpoints insname env) provides)) 

                              # other endpoints
                              (lib.mkMerge 
                                    (lib.mapAttrsToList 
                                        (eptype: eps: 
                                            lib.mkMerge (map (ep: { ${eptype}.${utils.epToString ep} = ep;}) eps)) 
                                        endpoints))
                          ];
            in {
                perEnv.${utils.envUID env} = {
                    inherit exposes reaches;
                };
                perVM.${utils.envHost env}.${utils.envUID env} = {inherit exposes reaches;};
            };
        in lib.mkMerge (lib.mapAttrsToList processDeployement deployements);



in {
    imports = [./options];
    naps.internal.endpoints = 
        lib.mkMerge (lib.mapAttrsToList processService config.naps.internal.services);

}
