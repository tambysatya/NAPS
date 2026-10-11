{flakeRoot, lib, inputs, config,...}:

let
    utils = import "${flakeRoot}/lib" {inherit lib inputs;};

    /* Should be replaced by a function consulting config.naps.envs.service.<serviceuid> */


    alldefaults = config.naps.global.services.defaults;
    mkDefaultServiceUID = 
        vmname: srvname: "def_${vmname}_${srvname}";
    mkDefaultServiceEnvs =
        vmname: vmconf: srvname: defaultOn: 
        lib.optionals (! builtins.elem srvname vmconf.without) (
            if defaultOn == "vm" then [{type = "vm"; host=vmname;}]
            else if defaultOn == "containers"
            then map (srvuid: {type="container"; host={vm=vmname; container=srvuid;};}) vmconf.containers
            else if defaultOn == "all"
            then mkDefaultServiceEnvs vmname vmconf srvname "containers" ++ mkDefaultServiceEnvs vmname vmconf srvname "vms"
            else throw "Wrong defaultOn value for ${srvname} [vmname=${vmname} defaultOn=${defaultOn}]"
        );

    computeHosts = 
        vmname: vmconf:
            with utils;
            let 
                getServiceEnv = srvid: config.naps.internal.envs.services.${srvid}.deployement;
                vmdefaults = vmDefaultsServices vmconf;
            in
            utils.mergeAll
                    (map 
                        (srvid: 
                            {${utils.serviceName config srvid}.deployements.${srvid} = getServiceEnv srvid;})
                        (vmconf.services ++ vmconf.containers ++ map (mkDefaultServiceUID vmname) vmdefaults)); #TODO add them in naps.topology.services

in {
   imports = [./options];
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
}
