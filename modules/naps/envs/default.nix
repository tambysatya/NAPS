{flakeRoot, lib, inputs, config, ...}:

let
    utils = import "${flakeRoot}/lib" {inherit inputs lib;};


    
    
    # srvuid is the name of the instance of the service which is the name of the environment
    # ONLY if the service runs within a container. Otherwise, the environment name is the VM
    extractName = srvuid: deploy: {${utils.envUID deploy} = deploy;};
    extractNames = attrs: utils.mergeAll (lib.mapAttrsToList extractName attrs);


    getPriority = srvuid: config.naps.topology.services.${srvuid}.priority;
    getTags = srvuid: config.naps.topology.services.${srvuid}.tags;

    mkVMEnv = vmname: {type="vm"; host=vmname;};
    mkContainerEnv = vmname: srvuid: {type="container"; host={vm=vmname; container=srvuid;}; };

    mkDeployementService = vmname: srvuid: 
        {
           ${srvuid} = {deployement = mkVMEnv vmname; priority = getPriority srvuid; tags = getTags srvuid;};
        };
    mkDeployementContainer = vmname: srvuid:
        {
            ${srvuid} = {deployement = mkContainerEnv vmname srvuid; priority = getPriority srvuid; tags = getTags srvuid;};
        };

    processVM = vmname: vmconf:
        let services = vmconf.services;
            containers = vmconf.containers;

        in  utils.mergeAll (map (mkDeployementService vmname) services ++ map (mkDeployementContainer vmname) containers);
            

    allEnvs = # uid => env
        let servicesEnvs = lib.mapAttrsToList (srvuid: {deployement, ...}: {${srvuid} = deployement;}) config.naps.envs.services;
            vms = map (vmname: {${vmname}=mkVMEnv vmname;}) (builtins.attrNames config.naps.topology.vms) ; 
        in #servicesEnvs;
           utils.mergeAll (servicesEnvs ++ vms); # we need to do this because some vms only have containers
    parts = utils.partitionAttrs (_: {type,...}: type == "vm") allEnvs;


in {
    imports = [./options.nix];

    naps.envs.services = utils.mergeAll (lib.mapAttrsToList processVM config.naps.topology.vms);
    naps.envs.vms = extractNames parts.right;
    naps.envs.containers = extractNames parts.wrong;
    naps.envs.all = extractNames allEnvs;
}
