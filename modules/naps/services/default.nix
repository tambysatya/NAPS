{flakeRoot, lib, inputs, config,...}:

let
    utils = import "${flakeRoot}/lib" {inherit lib inputs;};

    /* Should be replaced by a function consulting config.naps.envs.service.<serviceuid> */

    computeHosts = 
        vmname: vmconf:
            with utils;
            let 
                getServiceEnv = srvid: config.naps.envs.services.${srvid}.deployement;
            in
            utils.mergeAll
                    (map 
                        (srvid: 
                            {${utils.serviceName config srvid}.deployements.${srvid} = getServiceEnv srvid;})
                        (vmconf.services ++ vmconf.containers));

in {
   imports = [./options];
   config.naps.services = utils.mergeAll (lib.mapAttrsToList computeHosts config.naps.topology.vms);
}
