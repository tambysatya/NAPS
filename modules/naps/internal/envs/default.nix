{flakeRoot, lib, inputs, config, ...}:

let
    utils = import "${flakeRoot}/lib" {inherit inputs lib;};


    
    /* Generates all envs (for vm + containers) */
    generateEnvs =  
        vmname: vmconf:
        let
            containers = vmconf.containers;
            mkCTEnv = 
                i: ctname: {
                    ${ctname} = {
                        type = "container";
                        host = {
                           container = ctname;
                           vm = vmname;
                           publicHostAddress = vmconf.ip;
                           veth = "veth${lib.toString i}";
                        };
                        ip = "192.168.1.${lib.toString (i+50)}";
                    };
                };
            ctenvs = lib.imap mkCTEnv containers;
        in {
            vms.${vmname} = {
                type = "vm";
                host = vmname;
                ip = vmconf.ip;
            };
            containers = lib.mkMerge ctenvs;
        };


   

    /* Generates the services instances + adds instances for the default services.
       The deployement environment points to a vm or a container env defined above  (or in naps.internal.envs.{vms,containers} */
    allDefaults = lib.filterAttrs (_: default: default != null) config.naps.global.services.defaults; # map: Name -> DefaultType
    vmDefaults = builtins.attrNames (lib.filterAttrs (_: default: default == "all" || default == "vms") allDefaults);
    ctDefaults = builtins.attrNames (lib.filterAttrs (_: default: default == "all" || default == "containers") allDefaults);

    vmDefaultInstances =
        let vmDefServices = vmname: vmconf:
                lib.subtractLists vmconf.without vmDefaults; # we remove the default services that are explicitely disabled
            mkDefaultInstance = vmname: vmconf: srv: {
                    ${utils.default_service_id vmname srv} = {
                        deployement = config.naps.internal.envs.vms.${vmname};
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
                    deployement = config.naps.internal.envs.containers.${ctname};
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
                    deployement = config.naps.internal.envs.vms.${vmname};
                };
            };
            processCT = vmname: srvuid: {
                ${srvuid} = {
                    inherit (config.naps.topology.services.${srvuid}) priority tags is;
                    deployement = config.naps.internal.envs.containers.${srvuid};
                };
            };
            ret = utils.concatMapAttrsToList
                    (vmname: vmconf: 
                        map (processSrv vmname) vmconf.services ++ map (processCT vmname) vmconf.containers)
                     config.naps.topology.vms;
        in lib.mkMerge ret; 


in {
    imports = [./options.nix];

    naps.internal.envs = lib.mkMerge [
        (lib.mkMerge (lib.mapAttrsToList generateEnvs config.naps.topology.vms))
        {
            instances = lib.mkMerge [
                vmDefaultInstances 
                ctDefaultInstances 
                declaredInstances
            ];
        }
    ]; 
}
