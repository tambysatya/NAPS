{flakeRoot, lib, inputs, config, ...}:

let
    utils = import "${flakeRoot}/lib" {inherit inputs lib;};


    
   

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
    naps.internal.envs.vms = lib.mkMerge (lib.mapAttrsToList (vmname: _: {${vmname} = utils.mkVMEnv vmname;}) config.naps.topology.vms);
    naps.internal.envs.containers = vmContainers; #extractNames parts.wrong;
    naps.internal.envs.all = lib.mkMerge [config.naps.internal.envs.vms config.naps.internal.envs.containers];
}
