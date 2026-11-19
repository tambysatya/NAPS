{flakeRoot, lib, inputs, config, path, pkgs,...}:
let
    utils = import "${flakeRoot}/lib" {inherit lib inputs;};

        
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
        in lib.mkMerge (lib.mapAttrsToList processLinkType alllinks);

    processInputs = 
        insname: {provides, consumes}:
        let
            instance = config.naps.envs.instances.${insname};
            addToProviders = 
                linkname: {all.${linkname}.providers.${insname} = instance;};
            addToConsumers = 
                linkname: accesses:
                    {
                        all.${linkname}.consumers.${insname} = {
                            inherit instance accesses;
                        };
                    };
        in lib.mkMerge (map addToProviders provides ++ lib.mapAttrsToList addToConsumers consumes);

    generateAssets = 
        link: {consumers, providers}:
        let
            #genAssets :: Env -> [Env] -> Access -> Map Provider (Map AssetName ShippedAsset)
            genAssets = config.naps.lib.links.${link}.assets; 
            allHosts = lib.mapAttrsToList (_: instance: utils.insEnv instance) providers;
            processConsumers = 
                insname: {instance,accesses}: 
                    lib.mkMerge 
                        (lib.mapAttrsToList 
                            (accessuid: access: 
                                genAssets (utils.insEnv instance) allHosts access)
                            accesses);
        in lib.mkMerge 
            (lib.mapAttrsToList processConsumers consumers);
    generateEndpoints = 
        link: {consumers, providers}: 
        let
            endpoints = 
                lib.mapAttrs
                    (protocol: eplist: 
                        lib.mkMerge (map (ep: {${utils.epToString ep} = ep;})eplist))
                    config.naps.lib.links.${link}.endpoints;
            processConsumers = 
                insname: {instance,accesses}: {
                    ${insname}.reaches = endpoints;
                };
            processProviders = 
                insname: instance: {
                    ${insname}.exposes = endpoints;
                };
        in lib.mkMerge 
                (lib.mapAttrsToList processConsumers consumers ++ 
                 lib.mapAttrsToList processProviders providers);
in {
    imports = [./options];
    naps.links = lib.mkMerge [
        (lib.mkMerge (lib.mapAttrsToList processInputs config.naps.inputs.links))
    ];
    naps.inputs = {
        assets = lib.mkMerge (lib.mapAttrsToList generateAssets config.naps.links.all);
        endpoints = lib.mkMerge (lib.mapAttrsToList generateEndpoints config.naps.links.all);
    };
}
 
