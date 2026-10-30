{flakeRoot, lib, inputs, config, ...}:

let
    utils = import "${flakeRoot}/lib" {inherit lib inputs;};

    
    /*
    locatePathInEnv = # lookup which disk contains the file:
        env: dirpath: sharedP:
        let disks = config.naps.topology.vms.${utils.envHostUID env}.disks;
            shared = lib.filter (builtins.getAttr "shared") disks;
            diskHaveIt = lib.filter ({mount,...}: mount==dirpath) disks;

            #If the repository is explicitely mentioned as a mountpoint, it will be used. Otherwise, the shared repository will be used if possible.
            ret = if (diskHaveIt == []) && sharedP
                  then shared
                  else diskHaveIt;
            message = if sharedP
                            then "You need to allocate the repository manually on an individual volume or declare a volume as 'shared'."
                            else "The repository cannot be stored on a 'shared' volume. You need to allocate it manually on an individual volume.";
        in assert !(lib.length ret == 0) || throw ("Directory ${dirpath} not allocated in ${builtins.toJSON env}." + message);
           assert !(lib.length ret > 1)  || throw ("Directory ${dirpath} allocated multiple times in ${builtins.toJSON env}." + message);
           lib.head ret;

    processService = 
        {instances, persistent,...}:
        let processInstances =
            serviceUID: ins: utils.mergeAll (map (processPersistent serviceUID ins) persistent);
        in  utils.mergeAll (lib.mapAttrsToList processInstances instances);

    mkMountPoint = disk: if disk.mount == null
                       then "/srv/${lib.baseNameOf disk.path}"
                       else disk.mount;
            

    processPersistent = #uid -> env -> Attr
        serviceUID:
        ins:
        persistent@{path, shared,...}:
        let
            env = utils.insEnv ins;
            diruid = utils.directory_id serviceUID path;
            disk = locatePathInEnv env path shared;
            mount = mkMountPoint disk;

        in {
            perDirectory.${diruid} = {
                phys = disk.path; 
                path = if shared 
                       then "${mount}/${serviceUID}/${lib.removePrefix "/" path}"
                       else mount;
                bindTo = path; #should be ignored if path == bindTo TODO
                inherit (persistent) owner mode reload;
                inherit env mount;
             
            };
            perVM.${utils.envHostUID env}.${disk.path} = {
                inherit mount;
                type = disk.type;
                fs = disk.fs;
                resources = [diruid];
                inherit shared;
                inherit (disk) options;
            };
        };

    checkVM = 
        vmname:
        vmconf:
        let
            disks = vmconf.disks;
            dupVMMntPoint = utils.getFirstDupplicate (map mkMountPoint disks);
            dupSrvPersistent = utils.getFirstDupplicate 
                                    (lib.concatMap 
                                        (srvid: config.naps.internal.services.${utils.serviceName config srvid}.persistent) (vmconf.services ++ vmconf.containers));
        in [
            { assertion = dupVMMntPoint == null; message = "${dupVMMntPoint} is declared multiple times on ${vmname}";}
            { assertion = dupSrvPersistent == null; message = "${dupSrvPersistent} is declared by multiple services.";}
        ];
        */

in {
    imports = [./options];
    /*
    assertions = lib.concatLists (lib.mapAttrsToList checkVM config.naps.topology.vms);
    naps.internal.volumes = utils.mergeAll (map processService (builtins.attrValues config.naps.internal.services));
    */
    /*
    config.naps.volumes = {
        perDirectory = utils.mergeAll (libsmapAttrsToList processVM config.naps.topology.vms);
    };
    */
}
