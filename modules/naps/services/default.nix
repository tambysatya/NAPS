{flakeRoot, lib, inputs, config,...}:

let
    utils = import "${flakeRoot}/lib" {inherit lib inputs;};

    computeHosts = 
        vmname: vmconf:
            with utils;
            let 
                mkDeployementService = srvname: 
                    {type="vm"; host=vmname; priority = servicePriority config srvname; tags = serviceTags config srvname;};
                mkDeployementContainer = srvname:
                    {type="container"; host={vm=vmname; container=srvname;}; priority = servicePriority config srvname; tags = serviceTags config srvname;};
            in
            utils.mergeAll
                [(utils.mergeAll 
                    (map 
                        (srvid: 
                            {${utils.serviceName config srvid}.deployements.${srvid} = mkDeployementService srvid;})
                        vmconf.services))
                 (utils.mergeAll
                    (map 
                        (srvid: 
                            let service = utils.serviceName config srvid;
                            in {${service}.deployements.${srvid} = mkDeployementContainer srvid;})
                        vmconf.containers))]; #containers names are equal to the service
in {
   imports = [./options];
   config.naps.services = utils.mergeAll (lib.mapAttrsToList computeHosts config.naps.topology.vms);
}
