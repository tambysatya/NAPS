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


           /* Generates a map: EndpointType -> EndpointName -> InstanceName -> Instance */
           generateLinksHosts =
                insname: instance: linktype:
                let
                    linkendpoints = config.naps.links.${linktype}.endpoints; # EndpointType -> [Endpoint]
                in
                    lib.mapAttrsToList 
                        (eptype: eps:
                            {
                                ${eptype} = lib.mkMerge (map (ep: {${utils.epToString ep}.${insname} = instance;}) eps);
                            }) 
                        linkendpoints;



           processDeployement =
            insname: env:
            let
                instance = config.naps.internal.envs.instances.${insname};
                # Reached endpoints: perVM: endpointType -> hostname:port -> Endpoint
                reaches = lib.mkMerge
                            (lib.concatMap
                                (generateLinksEndpoints insname env)
                                (builtins.attrNames links));
                # Exposed endpoints: perVM: endpointType -> hostname:port -> Endpoint
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
                # EndpointType -> hostname:port -> ServiceID -> ServiceInstance                           
                hosts = lib.mkMerge [
                              # endpoints associated with the link of the service
                             (lib.mkMerge (lib.concatMap (generateLinksHosts insname instance) provides))
                              # other endpoints
                              (lib.mkMerge 
                                    (lib.mapAttrsToList 
                                        (eptype: eps: 
                                            lib.mkMerge (map (ep: { ${eptype}.${utils.epToString ep}.${insname} = instance;}) eps)) 
                                        endpoints))
                          ];
                # EndpointType -> hostname:port -> ServiceID -> ServiceInstance                           
                consumers = lib.mkMerge
                                (lib.concatMap 
                                    (generateLinksHosts insname instance)
                                    (builtins.attrNames links));
            in {
                inherit hosts consumers;
                perEnv.${utils.envUID env} = {
                    inherit exposes reaches;
                };
                perVM.details.${utils.envHost env}.${utils.envUID env} = {inherit exposes reaches;};
                perVM.global.${utils.envHost env} = {inherit exposes reaches;};
            };
        in lib.mkMerge (lib.mapAttrsToList processDeployement deployements);



in {
    imports = [./options];
    naps.internal.endpoints = 
        lib.mkMerge (lib.mapAttrsToList processService config.naps.internal.services);

}
