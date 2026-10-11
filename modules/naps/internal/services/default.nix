{flakeRoot, lib, inputs, config,...}:

let
    utils = import "${flakeRoot}/lib" {inherit lib inputs;};

    /* Should be replaced by a function consulting config.naps.envs.service.<serviceuid> */




    processInstance =
        srvuid: {deployement, is, ...}:{ 
            ${is}.deployements.${srvuid} = deployement;
        };
    copyService =  #copy the service declaration (from naps.services to naps.internal.services)
        srvname: srvconf: {${srvname} = srvconf;};


in {
    imports = [./options];
    config.naps.internal.services = lib.mkMerge (
            (lib.mapAttrsToList processInstance config.naps.internal.envs.instances)
            ++ (lib.mapAttrsToList copyService config.naps.services)
    );
}
   /*
   #config.naps.internal.envs.services = 
   config.naps.internal.services = utils.mergeAll [
                                        config.naps.services  
                                        (utils.mergeAll (lib.mapAttrsToList computeHosts config.naps.topology.vms))
                                    ];
   config.naps.topology.services =
        utils.mergeAll (lib.concatLists
                            (lib.mapAttrsToList 
                                (vmname: vmconf: map (srvname: {${mkDefaultServiceUID vmname srvname}.is = srvname;}) (vmDefaultsServices vmconf))
                                config.naps.topology.vms));
   config.naps.internal.envs.services =
        utils.mergeAll (lib.concatLists
                            (lib.mapAttrsToList 
                                (vmname: vmconf: map (srvname: {${mkDefaultServiceUID vmname srvname}.is = srvname;}) (vmDefaultsServices vmconf))
                                config.naps.topology.vms));
    */
