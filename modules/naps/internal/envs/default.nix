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
        let servicesEnvs = lib.mapAttrsToList (srvuid: {deployement, ...}: {${srvuid} = deployement;}) config.naps.internal.envs.instances;
            vms = map (vmname: {${vmname}=mkVMEnv vmname;}) (builtins.attrNames config.naps.topology.vms) ; 
        in #servicesEnvs;
           utils.mergeAll (servicesEnvs ++ vms); # we need to do this because some vms only have containers
    parts = utils.partitionAttrs (_: {type,...}: type == "vm") allEnvs;
    

    allDefaults = lib.filterAttrs (_: default: default != null) config.naps.global.services.defaults; # map: Name -> DefaultType
    vmDefaults = builtins.attrNames (lib.filterAttrs (_: default: default == "all" || default == "vms") allDefaults);
    ctDefaults = builtins.attrNames (lib.filterAttrs (_: default: default == "all" || default == "containers") allDefaults);

    vmDefaultInstances =
        let vmDefServices = vmname: vmconf:
                lib.subtractLists vmconf.without vmDefaults; # we remove the default services that are explicitely disabled
            mkDefaultInstance = vmname: vmconf: srv: {
                    ${utils.default_service_id vmname srv} = {
                        deployement = utils.mkVMEnv vmname;
                        priority = 100; #TODO
                        tags = [];
                        is = srv;
                    };
                };
            defaultServicesInstances = utils.concatMapAttrsToList (vmname: vmconf: map (mkDefaultInstance vmname vmconf) (vmDefServices vmname vmconf)) config.naps.topology.vms;
         in lib.mkMerge defaultServicesInstances;

    ctDefaultInstances = 
        let processCT = ctname: env: srvname: {
                ${utils.default_service_id ctname srvname} = {
                    deployement = env;
                    priority = 100; # TODO
                    tags = [];
                    is = srvname;
                };
            };
            defaultCTInstances = utils.concatMapAttrsToList (ctname: env: map (processCT ctname env) ctDefaults) config.naps.internal.envs.containers;
        in lib.mkMerge defaultCTInstances;

    declaredInstances = 
        let processSrv = vmname: srvuid: {
                ${srvuid} = {
                    inherit (config.naps.topology.services.${srvuid}) priority tags is;
                    deployement = utils.mkVMEnv vmname;
                };
            };
            processCT = vmname: srvuid: {
                ${srvuid} = {
                    inherit (config.naps.topology.services.${srvuid}) priority tags is;
                    deployement = utils.mkCTEnv vmname srvuid;
                };
            };
            ret = utils.concatMapAttrsToList
                    (vmname: vmconf: 
                        map (processSrv vmname) vmconf.services ++ map (processCT vmname) vmconf.containers)
                     config.naps.topology.vms;
        in lib.mkMerge ret; 

    vmContainers = 
        let processVM = vmname: vmconf: map (srvuid: { ${srvuid} = utils.mkCTEnv vmname srvuid; }) vmconf.containers;
        in lib.mkMerge (utils.concatMapAttrsToList processVM config.naps.topology.vms);
    vmEnvs = 
        let processVM = vmname: vmconf: map (srvuid: { ${srvuid} = utils.mkCTEnv vmname srvuid; }) vmconf.services;
        in lib.mkMerge (utils.concatMapAttrsToList processVM config.naps.topology.vms);


in {
    imports = [./options.nix];

    naps.internal.envs.instances = lib.mkMerge [
        vmDefaultInstances 
        ctDefaultInstances 
        declaredInstances
    ]; 
    naps.internal.envs.vms = lib.mkMerge (lib.mapAttrsToList (vmname: _: {${vmname} = mkVMEnv vmname;}) config.naps.topology.vms);
    naps.internal.envs.containers = vmContainers; #extractNames parts.wrong;
    naps.internal.envs.all = lib.mkMerge [config.naps.internal.envs.vms config.naps.internal.envs.containers];
}
