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

    generateOutputs = 
        envuid: alllinks:
        let
            processLinkType = 
                linktype: accesses:
                let
                    allReloads = lib.unique (utils.concatMapAttrsToList (accessname: access: access.reload) accesses);
                    waitLinkUp = config.naps.links.${linktype}.waitLinkUp;
                in {
                    config.systemd.services."wait-uplink-${linktype}" = {
                        description = "Waiting for link ${linktype} to be up";
                        wants = ["network.target"];
                        after = ["network.target"];
                        before = allReloads;
                        requiredBy = allReloads;
                        serviceConfig = {
                            Type = "oneshot";
                            RemainAfterExit = "yes";
                            ExecStart = pkgs.writeShellScript "wait-uplink-${linktype}" waitLinkUp;
                        };
                    };
                };
        in utils.mergeAll (lib.mapAttrsToList processLinkType alllinks);

in {
    imports = [./options];
    naps.links = lib.mkMerge [
        #(lib.mkMerge (lib.mapAttrsToList processService config.naps.internal.services))
        #{outputs = utils.mergeAll [(lib.mapAttrs generateOutputs config.naps.internal.links.perEnv)];}
    ];
}
 
