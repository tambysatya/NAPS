/* Disk partitionning */
{lib, inputs, config, naps, registry, vmname, vmconf,...}:
let
    root = {
        type = "disk";
        device = "/dev/vda"; # /dev/sdb

            content = {
                type = "gpt";

                partitions = {
                    boot = {
                        size = "1G";
                        type = "EF00";
                        content = {
                            type = "filesystem";
                            format = "vfat";
                            mountpoint = "/boot";
                            mountOptions = ["umask=0077"];
                        };
                    }; 
                    swap = {
                        size = "4G";
                        content = {
                            type = "swap";
                        };
                    };
                    root = {
                        size = "100%";
                        content = {
                            type = "filesystem";
                            format = "ext4";
                            mountpoint = "/";
                        };
                    };
                };
            };
    };
    processQcow = 
        mountpoint:
        qcow@{name, size, target}:
        {
            "${target.device}" = {
                type = "disk";
                device = "/dev/${target.device}";
                content = {
                    type = "filesystem";
                    format = target.fsType;
                    mountpoint = mountpoint;
                };
            };
        };
    volumes = registry.vms.${vmname}.attachedVolumes;
    processVolumes = lib.mapAttrs processVolume volumes;
    processVolume =
        mountpoint:
        vol@{fsType, options, vmDevice, ...}:
        {
            device = "/dev/${vmDevice}";
            type = "disk";
            content = {
                type  = "filesystem";
                format = fsType;
                inherit mountpoint;
            };
        };

in
{

    imports = [inputs.disko.nixosModules.disko];
    boot.initrd.availableKernelModules = [ "ahci" "xhci_pci" "virtio_pci" "sr_mod" "virtio_blk" ];

    disko.devices.disk =
        lib.mkMerge [
            {
                vda = root;
            }
            processVolumes
            #(lib.mkMerge 
            #    (lib.mapAttrsToList processQcow vmconf.persistentVolumes.qcows))
        ];
}
