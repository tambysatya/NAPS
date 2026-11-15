{flakeRoot, lib, inputs, config, pkgs, ...}:
let
    types = import "${flakeRoot}/lib/types" {inherit lib inputs;};
    utils = import ./lib {inherit flakeRoot lib inputs;};
    generateFirewall = 
        vmenv: {forward, reverse}:
        let
            # Reverse proxies are always open both on the host and the container 
            processFwReverseInstance =
                epname: insname: ins:
                let
                    port = config.naps.endpoints.all."https".${epname}.port;
                in lib.mkMerge [
                   # On containers only we open the backend port (not on native instances)
                    (lib.optionalAttrs 
                        (utils.runsInContainer ins) 
                        {
                            ${utils.insEnvUID ins}."eth0".tcp = [port];
                        })
                    /* We always open the 443 public port on the host
                       (the only way to reach https endpoints) */
                    {
                        ${utils.envUID vmenv}."enp1s0".tcp = [443];
                    }

                ];
            fwReverse = endpoint: instances:
                lib.mkMerge (lib.mapAttrsToList (processFwReverseInstance endpoint) instances);
            allReverseFirewall = lib.mkMerge (lib.mapAttrsToList fwReverse reverse);

            fwForward =
                localenvuid: endpoints:
                let 
                    localenv = config.naps.internal.envs.all.${localenvuid};
                    ctFwdPorts = 
                        lib.unique
                            (lib.mapAttrsToList (epname: ep: ep.port) endpoints);
                    fwCtForward =
                        port: {
                            ${utils.envHostUID localenv}."ve-${localenvuid}".tcp = [443];
                            #${utils.envHostUID localenv}.${localenv.host.veth}.tcp = [443]; #TODO use veth0, veth1...
                        };
                in lib.optionalAttrs (utils.isContainer localenv) (lib.mkMerge (map fwCtForward ctFwdPorts));
            allForwardFirewall = lib.mkMerge (lib.mapAttrsToList fwForward forward);
        in lib.mkMerge [allReverseFirewall allForwardFirewall];

        reverseFirewall = 
            vmenv: reverse:
            let
                # Reverse proxies are always open both on the host and the container 
                processFwReverseInstance =
                    epname: insname: ins:
                    let
                        port = config.naps.endpoints.all."https".${epname}.port;
                    in lib.mkMerge [
                       # On containers only we open the backend port (not on native instances)
                        (lib.optionalAttrs 
                            (utils.runsInContainer ins) 
                            {
                                ${utils.insEnvUID ins}."eth0".tcp = [port];
                            })
                        /* We always open the 443 public port on the host
                           (the only way to reach https endpoints) */
                        {
                            ${utils.envUID vmenv}."enp1s0".tcp = [443];
                        }

                    ];
                fwReverse = endpoint: instances:
                    lib.mkMerge (lib.mapAttrsToList (processFwReverseInstance endpoint) instances);
                allReverseFirewall = lib.mkMerge (lib.mapAttrsToList fwReverse reverse);
            in allReverseFirewall;
in {
    inherit generateFirewall; #TODO (partially split between reverseFirewall)
};



