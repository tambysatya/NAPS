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
        

    /* Selects a disk suitable for storing the resource.
        Returns the disk identifier host:location  */
    assignResourceToDisk =
        rname: resource@{path, instance, shareable,...}:
        let
            vmname = utils.insHostUID instance;
            vmconf = config.naps.topology.vms.${vmname};
            vmdisks = vmconf.disks;
            parts = lib.partition ({shared, ...}: shared) vmdisks;
            shared = parts.right;
            individuals = lib.filter ({mount,...}: mount == path) parts.wrong;

            # due to lazyness, the computation of "selected" should raise an error if the asserts are not verified
            selected = builtins.elemAt (individuals ++ shared) 0; # always select the individual volume first if there is one
        in assert (shareable || individuals != []) || throw "No persistent volume for resource ${rname} on ${vmname}. This resource REQUIRES an individual volume";
           assert (!shareable || (individuals ++ shared != [] )) || throw "No persistent volume for resource ${rname} on ${vmname}. Either assign a dedicated volume on ${vmname} or enable sharing.";
           "${vmconf.host}:${selected.location}";

    processResource = 
        rname: resource@{instance,...}: 
        let
            env = utils.insEnv instance;
            dname = assignResourceToDisk rname resource;
            disk = config.naps.internal.persistent.disks.${dname};
        in {
            attachments.${utils.insEnvUID instance}.${dname} = disk;
            resourcesLocation.${rname} = disk;
            disks.${dname}.${rname} = resource;
        };


    
in {
    imports = [./options];
    naps.internal.persistent = 
        lib.mkMerge [
            (lib.mkMerge (utils.concatMapAttrsToList processVM config.naps.topology.vms))
            (lib.mkMerge (utils.concatMapAttrsToList processService config.naps.internal.services))
            {ir = lib.mkMerge (lib.mapAttrsToList processResource config.naps.internal.persistent.resources);} 
        ];
}
