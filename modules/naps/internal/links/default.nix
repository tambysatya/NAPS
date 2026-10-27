{flakeRoot, lib, inputs, config, path, pkgs,...}:
let
    utils = import "${flakeRoot}/lib" {inherit lib inputs;};

    processService = 
        srvname: {provides, instances, links, ...}:
        let processIns = 
                insuid: ins: utils.concatMapAttrsToList (processLinkType insuid ins) links;
            processLinkType =
                insuid: ins: linktype: links: map (processLink insuid ins linktype) links;
            processLink =
                insuid: ins: linktype: link: 
                let
                    accessuid = config.naps.links.${linktype}.accessuid link;
                in 
                    {
                        perEnv.${utils.insEnvUID ins}.${linktype}.${accessuid} = link;
                        perVM.${utils.insHostUID ins}.${linktype}.${utils.insEnvUID ins}.${accessuid} = link;
                        all.${linktype}.requesters.${insuid} = utils.insEnv ins;
                        
                    };
            processProvides = 
                name: {
                    all.${name}.providers = instances;
                };

        in lib.mkMerge [
                (lib.mkMerge
                    (utils.concatMapAttrsToList processIns instances))
                (lib.mkMerge 
                    (map processProvides provides))
            ];

in {
    imports = [./options];
    naps.internal.links = lib.mkMerge [
        (lib.mkMerge (lib.mapAttrsToList processService config.naps.internal.services))
    ];
}
 
