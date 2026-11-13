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
        in utils.mergeAll (lib.mapAttrsToList processLinkType alllinks);

    processInputs = 
        insname: {provides, consumes}:
        let
            instance = config.naps.envs.instances.${insname};
            addLinkGeneralInfo =
                linkname: 
                let
                    inherit (config.naps.lib.links.${linkname}) endpoints; # Map Protocol [Endpoints];
                in {
                    ${linkname}.endpoints = 
                        # Need to assign each endpoint to an unique name using epToString
                        lib.mapAttrs (proto: eps: lib.mkMerge (map (ep: {${utils.epToString ep} = ep;}) eps)) endpoints;
                   };
            addToProviders = 
                linkname:
                lib.mkMerge [
                    {all = addLinkGeneralInfo linkname;}
                    {all.${linkname}.providers.${insname} = instance;}
                ];
            addToConsumers = 
                linkname: accesses:
                lib.mkMerge [
                    {all = addLinkGeneralInfo linkname;}
                    {
                        all.${linkname}.consumers.${insname} = {
                            inherit instance accesses;
                        };
                    }
                ];
        in lib.mkMerge (map addToProviders provides ++ lib.mapAttrsToList addToConsumers consumes);
in {
    imports = [./options];
    naps.links = lib.mkMerge [
        (lib.mkMerge (lib.mapAttrsToList processInputs config.naps.inputs.links))
        #(lib.mkMerge (lib.mapAttrsToList processService config.naps.internal.services))
        #{outputs = utils.mergeAll [(lib.mapAttrs generateOutputs config.naps.internal.links.perEnv)];}
    ];
}
 
