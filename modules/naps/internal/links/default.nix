{flakeRoot, lib, inputs, config, path, pkgs,...}:
let
    utils = import "${flakeRoot}/lib" {inherit lib inputs;};

/*
    getHosts = 
        let
            processSrv =
                srvname: srvconf@{provides, deployements, endpoints,...}: 
                utils.concatMapAttrsToList 
                    (eptype: eps:
                        lib.concatMap
                            ({link, hostname, port,...}:
                             lib.optionals (link != null)
                                (map 
                                 {
                                   ${link} = lib.mapAttrsToList (_: env: {inherit env; endpoint = {type=eptype; inherit hostname port;};}) deployements;
                                 }
                                 provides )
                            ) 
                            eps)
                    endpoints;
        in utils.concatMapAttrsToList processSrv config.naps.internal.services;
*/    
    processService = 
        srvname: {provides, deployements, links, ...}:
        let processEnv = 
                insuid: env: utils.concatMapAttrsToList (processLinkType insuid env) links;
            processLinkType =
                insuid: env: linktype: links: map (processLink insuid env linktype) links;
            processLink =
                insuid: env: linktype: link: 
                let
                    accessuid = config.naps.links.${linktype}.accessuid link;
                in 
                    {
                        perEnv.${utils.envUID env}.${linktype}.${accessuid} = link;
                        perVM.${utils.envHost env}.${linktype}.${utils.envUID env}.${accessuid} = link;
                        all.${linktype}.requesters.${insuid} = env;
                        
                    };
            processProvides = 
                name: {
                    all.${name}.providers = lib.mapAttrs (ins: _: config.naps.internal.envs.instances.${ins}) deployements;
                };

        in lib.mkMerge [
                (lib.mkMerge
                    (utils.concatMapAttrsToList processEnv deployements))
                (lib.mkMerge 
                    (map processProvides provides))
            ];

in {
    imports = [./options];
    naps.internal.links = lib.mkMerge [
        (lib.mkMerge (lib.mapAttrsToList processService config.naps.internal.services))
    ];
}
 
