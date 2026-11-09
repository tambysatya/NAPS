{lib, inputs, flakeRoot, config, ...}:

let
    utils = import ./lib {inherit flakeRoot lib inputs;};

    processVM = 
        vmname: {disks, host, ...}:
        let 
            processDisk = 
                disk@{type, location,...}: letter: {
                    disks."${host}:${location}" = disk // {env = config.naps.internal.envs.all.${vmname}; inherit letter;};
                };
        in lib.zipListsWith processDisk disks (lib.stringToCharacters "bcdefghiklmnopqrstuvwxyz");

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
            attachments = {
                perEnv.${utils.insEnvUID instance} = {
                    disks.${dname} = disk;
                    resources.${rname} = resource;
                };
                perVM.${utils.insHostUID instance} = {
                    disks.${dname} = disk;
                    resources.${rname} = resource;
                };
            };
            resourcesLocation.${rname} = disk;
            disks.${dname}.${rname} = resource;
        };

    generateVMDiskoConfig = 
        vmname: attachments@{disks, resources}: # Map DiskUID Disk, Map ResourceUID Resource
        {
            ${vmname}.config = {
                boot.initrd.availableKernelModules = [ "ahci" "xhci_pci" "virtio_pci" "sr_mod" "virtio_blk" ];
                disko.devices.disk = 
                    lib.mkMerge ([utils.genDiskoRoot] ++ 
                                 map 
                                    utils.genDisko 
                                    (builtins.attrValues disks));
            };
        };

    generateResourceConfig =
        rname: resource@{instance, path, ...}:
        let
            disk = config.naps.internal.persistent.ir.resourcesLocation.${rname};
            vmname = utils.insHostUID instance;
            envuid = utils.insEnvUID instance;
            location = if disk.shared then "${disk.mount}/${rname}" else disk.mount;
        in {
            ${vmname}.config = {
                # container-mounts
                containers = lib.optionalAttrs (utils.runsInContainer instance)
                    {
                        ${envuid}.bindMounts.${path} = {
                            hostPath = location;
                            isReadOnly = false;
                        };
                    };
                # if stored on a shareable disk, the resource should be initialized + bind-mounted
            };
        };

    generateVMSharedResourcesInitConfig = # initializes shared volumes if their resources does not exist
        vmname: {resources,...}:
        let
            locations = config.naps.internal.persistent.ir.resourcesLocation;
            # a resource is shared when living on a shared volume
            isShared = rname: resource: locations.${rname}.shared;
            sharedResources = lib.filterAttrs isShared resources;

            # shared resources used by a native service should be bind-mounted using systemd-mount
            sharedUsedNatively = lib.filterAttrs (_: resource@{instance,...}: ! utils.runsInContainer instance) sharedResources;

            service = utils.mkInitDirServices config locations sharedResources;
        in lib.optionalAttrs (sharedResources != {}){
            ${vmname}.config.systemd = {
                services = service;
                mounts = lib.mapAttrsToList (utils.genMountService locations) sharedUsedNatively;
            };
        };


    
in {
    imports = [./options];
    naps.internal.persistent = 
        lib.mkMerge [
            (lib.mkMerge (utils.concatMapAttrsToList processVM config.naps.topology.vms))
            (lib.mkMerge (utils.concatMapAttrsToList processService config.naps.internal.services))
            {ir = lib.mkMerge (lib.mapAttrsToList processResource config.naps.internal.persistent.resources);} 
            # Disko configuration of VMs
            {outputs = lib.mkMerge (lib.mapAttrsToList generateVMDiskoConfig config.naps.internal.persistent.ir.attachments.perVM);} 
            # Container configurations
            {outputs = 
                lib.mkMerge 
                    (utils.concatMapAttrsToList 
                        (envname: {resources, ...}: lib.mapAttrsToList generateResourceConfig resources)
                        config.naps.internal.persistent.ir.attachments.perEnv);} 
            # Initialization of the shared volumes + bind-mounts for native services sharing their storage
            {outputs = lib.mkMerge (lib.mapAttrsToList generateVMSharedResourcesInitConfig config.naps.internal.persistent.ir.attachments.perVM);} 
        ];
}
