{flakeRoot, lib, inputs, config, ...}:

let
    utils = import ./lib {inherit flakeRoot inputs lib;};


    
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
                           privateSubnet = "192.168.1.${lib.toString (4*i)}/30";
                           privateHostAddress = "192.168.1.${lib.toString (4*i+1)}";
                           veth = "veth${lib.toString i}";
                        };
                        ip = "192.168.1.${lib.toString (4*i+2)}";
                    };
                };
            ctenvs = lib.imap0 mkCTEnv containers;
        in {
            vms.${vmname} = {
                type = "vm";
                host = vmname;
                ip = vmconf.ip;
            };
            containers = lib.mkMerge ctenvs;
        };

    declaredInstances = 
        let processSrv = vmname: srvuid: {
                ${srvuid} = {
                    inherit (config.naps.topology.services.${srvuid}) priority tags is;
                    deployement = config.naps.envs.vms.${vmname};
                };
            };
            processCT = vmname: srvuid: {
                ${srvuid} = {
                    inherit (config.naps.topology.services.${srvuid}) priority tags is;
                    deployement = config.naps.envs.containers.${srvuid};
                };
            };
            ret = utils.concatMapAttrsToList
                    (vmname: vmconf: 
                        map (processSrv vmname) vmconf.services ++ map (processCT vmname) vmconf.containers)
                     config.naps.topology.vms;
        in lib.mkMerge ret; 

    addInstanceToService =
        srvuid: srv@{deployement, is, ...}:{ 
            ${is}.instances.${srvuid} = srv;
        };
in {
    imports = [./options.nix];
    naps.envs = lib.mkMerge [
            (lib.mkMerge (lib.mapAttrsToList generateEnvs config.naps.topology.vms))
            {
                instances = declaredInstances;
                all = lib.mkMerge [config.naps.envs.vms config.naps.envs.containers];
                outputs = lib.mkMerge (
                            lib.mapAttrsToList (utils.initializeVMNetworking config) config.naps.envs.vms ++
                            lib.mapAttrsToList (utils.initializeContainerNetworking config) config.naps.envs.containers);
            }
        ]; 
    naps.services = lib.mkMerge (lib.mapAttrsToList addInstanceToService config.naps.envs.instances);
}
