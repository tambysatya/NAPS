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
        envuid: {provides, consumes}:
        let
            addLink =
                linkname:
                let
                    endpoints = config.naps.lib.links.${linkname}.endpoints;
                in {};
        in {};
in {
    imports = [./options];
    naps.links = lib.mkMerge [
        #(lib.mkMerge (lib.mapAttrsToList processService config.naps.internal.services))
        #{outputs = utils.mergeAll [(lib.mapAttrs generateOutputs config.naps.internal.links.perEnv)];}
    ];
}
 
