{lib, inputs, flakeRoot, config, ...}:

let
    utils = import "${flakeRoot}/lib" {inherit lib inputs;};

    processVM = 
        vmname: {disks, host, ...}:
        let 
            processDisk = 
                disk@{type, location,...}: {
                    disks."${host}:${location}" = disk // {env = config.naps.internal.envs.all.${vmname};};
                };
        in map processDisk disks;

    processService = 
        srvname: srvconf@{persistent,instances,...}:
        let processInstance =
                insname: ins: lib.mapAttrsToList (processPersistent insname ins) persistent;
            processPersistent = 
                insname: ins: path: resource: {
                    resources."${insname}:${path}" = resource // {instance = ins; inherit path;};
                };
        in utils.concatMapAttrsToList processInstance instances;
        
    
in {
    imports = [./options];
    naps.internal.persistent = 
        lib.mkMerge [
            (lib.mkMerge (utils.concatMapAttrsToList processVM config.naps.topology.vms))
            (lib.mkMerge (utils.concatMapAttrsToList processService config.naps.internal.services))
        ];
}
