/* Volumes processing: generation of systemd-mount services  and volumes initializations*/


{inputs, lib, pkgs, naps, registry, ...}:
let

    utils = import "${inputs.self.outPath}/lib/utils.nix" {inherit lib;};
    vars = import "${inputs.self.outPath}/lib/vars.nix" {inherit inputs lib pkgs naps registry;};

    compileVolumes = vmname:
        let
            ops = [
                        (mountVolumes vmname)
                        (generateInitSourceDir vmname)
                        (generateSystemdBindMount vmname)
                  ];
        in lib.mkMerge ops;

    /* Mounts a directory in sourcedir into the where destination */
    generateSystemdBindMount = vmname:
        let dirs = registry.vms.${vmname}.persistentDirectories;
            genNativeMount =
                where: {srcPath, reload, ...}:
                    {
                        inherit where;
                        what = srcPath;
                        options = "bind";
                        type = "none";
                        after = ["init-volumes.service"];
                        requires = ["init-volumes.service"];
                        before = reload;
                        requiredBy = reload;
                    };
            genContainerMount =     
                where: {srcPath, service,...}: {
                    containers.${service}.bindMounts.${where} = {
                        hostPath = srcPath;
                        isReadOnly = false;
                    };
                    systemd.services."container@${service}" = {
                        after = ["init-volumes.service"];
                        requires = ["init-volumes.service"];
                    };
                };
            processDir =
                where: args@{deployement,...}:
                    if deployement == "native"
                        then genNativeMount where args
                        else genContainerMount where args;
        in lib.mkMerge (lib.mapAttrsToList processDir dirs);
                        
    # Initializes the persistent volumes if they are empty
    generateInitSourceDir = vmname:
        let dirs = registry.vms.${vmname}.persistentDirectories;
            script = lib.concatMapStringsSep "\n"
                            ({srcPath, mode, owner,...}:
                                ''
                                    if [[ ! -d ${srcPath} ]]; then
                                        mkdir -p ${srcPath}
                                        #chown ${owner} ${srcPath}
                                        #cmod ${mode} ${srcPath}
                                    fi
                                '')
                            (builtins.attrValues dirs);
            dependencies = map ({srcMountDir,...}: "${utils.pathToMountUnit srcMountDir}") (builtins.attrValues dirs);
        in  
            {
                systemd.services."init-volumes" = {
                    description = "Initializes empty persistent volumes before bind-mounting files";
                    after = dependencies;
                    requires = dependencies;
                    serviceConfig.Type = "oneshot";
                    inherit script;
                };
            };
    # Generates a fstab
    mountVolume = 
        mountpoint:
        vol@{deviceType, fsType, options, vmDevice,...}:
            {
                fileSystems = {
                    "${mountpoint}" = {
                        device = "/dev/${vmDevice}";
                        inherit options fsType;
                    };
                };
            };
    mountVolumes = vmname:
        lib.mkMerge (lib.mapAttrsToList mountVolume registry.vms.${vmname}.attachedVolumes);
in {
    inherit compileVolumes;
}
