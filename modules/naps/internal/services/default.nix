{flakeRoot, lib, inputs, config,...}:

let
    utils = import "${flakeRoot}/lib" {inherit lib inputs;};

    /* Should be replaced by a function consulting config.naps.envs.service.<serviceuid> */


    alldefaults = config.naps.global.services.defaults;
    mkDefaultServiceUID = 
        vmname: srvname: "def_${vmname}_${srvname}";

    computeHosts = 
        vmname: vmconf:
            with utils;
            let 
                getServiceEnv = srvid: config.naps.internal.envs.services.${srvid}.deployement;
                vmdefaults = lib.subtractLists vmconf.without alldefaults;
            in
            utils.mergeAll
                    (map 
                        (srvid: 
                            {${utils.serviceName config srvid}.deployements.${srvid} = getServiceEnv srvid;})
                        (vmconf.services ++ vmconf.containers ++ map mkDefaultServiceUID vmdefaults)); #TODO add them in naps.topology.services

in {
   imports = [./options];
   config.naps.internal.services = utils.mergeAll [
                                        config.naps.services  
                                        (utils.mergeAll (lib.mapAttrsToList computeHosts config.naps.topology.vms))
                                    ];
}
