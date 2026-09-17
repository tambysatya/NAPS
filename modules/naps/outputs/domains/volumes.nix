
{flakeRoot, lib,inputs, config,...}:

let 
    utils = import "${flakeRoot}/lib" {inherit lib inputs;};

    /* Volume creation */
    generateQcow =
        vmname: host: 
        {name, size, persistentP ? false, ...}:
               {
                    "${vmname}_${name}"= {
                        name = "${vmname}_${name}";
                        pool = "\${libvirt_pool.default_${host}.name}";
                        capacity = size;
                        provider = "libvirt.${host}";
                        lifecycle.prevent_destroy = persistentP;
                    };
                };
    generateRootQcow=
        vmname: host: generateQcow vmname host {name="root"; size=20*1024*1024*1024;};



    createVMVolumes =
        vmname: deploy:
        let hostname = config.naps.topology.vms.${vmname}.host;
            qcows = lib.filter ({type,...}: type == "qcow") deploy.storage.mappings;
            root = generateRootQcow vmname hostname;
            defaultSize = 100*1024*1024;
            processQcowMapping =
                {host, type, ...}: # note: host in the mappings represents the name of the volume from the host side (TODO)
                generateQcow vmname hostname {name=host; size=defaultSize;  persistentP = true;};
        in utils.mergeAll ([root] ++ map processQcowMapping qcows);
            
    /* Volume Attach */
            
    attachIsoAndRoot =
        vmname: hostname: 
        [
              { /* Custom Live Install */
                device = "cdrom";
                source = {
                  file = {file = "\${libvirt_volume.iso_${hostname}.path}";};
                };
                target = {dev = "sda"; bus = "sata";};
                readonly = true;
              }
              { /* Volume "/"  */
                source = {
                  volume = {
                    volume = "\${libvirt_volume.${vmname}_root.name}";	
                    pool = "\${libvirt_pool.default_${hostname}.name}";
                  };
                    
                };
                target = {dev = "vda"; bus="virtio";};
              }
        ];
    attachQCow = 
        vmname: hostname:
        {host, letter,...}: # host is the reference of the volume on the KVM hyperviser (e.g. "persistent")
            { 
                source = {
                  volume = {
                    volume = "\${libvirt_volume.${vmname}_${host}.name}";	
                    pool = "\${libvirt_pool.default_${hostname}.name}";
                  };
                    
                };
                target = {dev = "vd${letter}"; bus="virtio";};
            };

    attachDisk = 
        {host, letter, ...}: # host is the reference of the volume on the KVM hyperviser (e.g. "/dev/sdb")
        {
            source = {
              block = {
                dev = host;
              };
            };
            target = {dev = "vd${letter}"; bus="virtio";};
            driver = {
              name = "qemu";
              type = "raw";
              cache = "none";
              io = "native";
              discard = "unmap";
                
            };
        };

    attachVMVolumes =
        vmname: deploy:
        let hostname = config.naps.topology.vms.${vmname}.host;
            processVolume =
                vol@{type,...}: if type == "disk" then attachDisk vol else attachQCow vmname hostname vol;
        in {
                ${vmname}.devices.disks = attachIsoAndRoot vmname hostname ++ map processVolume deploy.storage.mappings;
        };
    vms = lib.filterAttrs (_: {env, ...}: env.type == "vm") config.naps.deploy.systems;

in {
    naps.outputs.domains = {
        resource.libvirt_volume = utils.mergeAll (lib.mapAttrsToList createVMVolumes vms);
        resource.libvirt_domain = utils.mergeAll (lib.mapAttrsToList attachVMVolumes vms);
    };
}
