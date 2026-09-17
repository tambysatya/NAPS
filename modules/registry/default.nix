{lib, config, inputs,...}:
let

    naps = config.naps;
    utils = import "${inputs.self.outPath}/lib/utils.nix" {inherit lib;};
    napstypes = import "${inputs.self.outPath}/lib/naps/types.nix" {inherit lib;};
    modules = lib.map (name: "${inputs.self.outPath}/services/${name}/register.nix") napstypes.serviceNames;
    #modules = lib.map (name: "${inputs.self.outPath}/services/${name}/register.nix") (lib.unique (services ++ containers)); #enables only the services activated by the naps


    processDirs = 
        vmname: vmconf:
        deployement:
        servicename:
        let
           volumes = config.registry.services.${servicename}.volumes;
           processDir = dir@{mode, owner, path, reload}:
                let
                   locations = lib.filter
                                    ({mapping,...}:
                                        builtins.elem path (map (builtins.getAttr "sys") mapping))
                                    (vmconf.persistentVolumes.qcows ++ vmconf.persistentVolumes.disks);
                   location = lib.head locations;
                   vollocation = (lib.head (lib.filter ({vol,sys}: sys == path) location.mapping)).vol;
                in
                assert (locations != []) || throw "Required persistent directory ${path} by ${servicename} not found on ${vmname}";
                assert (lib.length locations == 1) || throw "Persistent directory ${path} by ${servicename} found multiple times on ${vmname}";
                {
                    "${vmname}".persistentDirectories."${path}" = {
                       srcPath = "${location.mount.dir}/${lib.removePrefix "/" vollocation}";
                       srcMountDir = location.mount.dir;
                       inherit owner mode reload deployement;
                       service = servicename;
                    };
                };
            
        in lib.mkMerge (map processDir volumes);
    processQcow = 
        vmname: vmconf:
        qcow@{name, size, mount, mapping}:
        letter:
        let
           mntdir = mount.dir;
        in
        {
            ${vmname}.attachedVolumes."${mntdir}" = {
                hostDevice = "${vmname}_${name}";
                vmDevice = "vd${letter}";
                inherit (mount) options fsType;
                deviceType = "qcow";
            };
        };
    processDisk = 
        vmname: vmconf:
        disk@{src, mount, mapping}:
        letter:
        let mntdir = mount.dir;
        in {
            ${vmname}.attachedVolumes."${mntdir}" = {
                hostDevice = src;
                vmDevice = "vd${letter}";
                inherit (mount) options fsType;
                deviceType = "disk";
            };
        };
    processVolumes = 
        vmname: vmconf:
        let
            # [Letter -> Volume]
            mkVolumeFromLetter = map (processQcow vmname vmconf) (vmconf.persistentVolumes.qcows)
                               ++ map (processDisk vmname vmconf) (vmconf.persistentVolumes.disks);
        
        in lib.mkMerge (lib.zipListsWith (f: x: f x) mkVolumeFromLetter (lib.stringToCharacters "bcdefghijklmnopqrstuvwxyz"));

    compileVMsHosts = 
        vmname: vmconf:
            let 
                services = vmconf.services;
                containers = vmconf.containers;
            in lib.mkMerge [
                (lib.mkMerge
                   (lib.map (name: {"${name}".hosts.vms = [vmname];}) services))
                (lib.mkMerge 
                    (lib.map(name: {"${name}".hosts.containers = [vmname];}) containers))
            ];


    compileVMsFiles =
        vmname: vmconf:
            let 
                services = vmconf.services;
                containers = vmconf.containers;
            in lib.mkMerge [
                (lib.mkMerge 
                    (map (processDirs vmname vmconf "native") (vmconf.services))) 
                (lib.mkMerge 
                    (map (processDirs vmname vmconf "container") (vmconf.containers))) 
                (processVolumes vmname vmconf)

            ];


in 

{
imports = [./options]++ modules;    
#config.registry.services = lib.mkMerge (lib.mapAttrsToList compileVMsHosts naps.vms);
#config.registry.vms = lib.mkMerge (lib.mapAttrsToList compileVMsFiles naps.vms);
}
