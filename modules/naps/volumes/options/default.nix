{flakeRoot, lib, inputs, config,...}:

let
    libtypes = import "${flakeRoot}/lib/types" {inherit lib inputs;};
    types = lib.types // libtypes;

    resourceUID = types.str;

    dirInfos = types.submodule {
       options = {
            phys = lib.mkOption {
                description = "Physical device where the directory lives on the KVM host";
                type = types.str;
            };
            path = lib.mkOption {
                description = "Where the directory lives";
                type = types.str;
                example = "/srv/persistent/dirA";
            };
            bindTo = lib.mkOption {
                description = "If the directory is stored on a shared volume, where to bind-mount it";
                type = types.nullOr (types.str);
                example = "/var/lib/nextcloud/config";
                default = null;
            };
            env = lib.mkOption {
                description = "Environment requesting the directory. In containers, the directory will be bound within the container";
            };
            mode = types.dirmode;
            inherit (types) owner reload;
            mount = lib.mkOption {
                description = "Path to the mount point";
                type = types.str;
            };
       };   
    };

    vmDisk = types.submodule {
        options = {
            inherit (types) owner reload;
            mount = lib.mkOption {
                description = "Path to the mount point";
                type = types.str;
            };
            type = lib.mkOption {
                description = "Type of the device";
                type = types.enum ["qcow" "disk"];
            };
            resources = lib.mkOption {
                description = "Unique identifier of the resources present on the disk";
                type = types.listOf resourceUID;
                default = [];
            };
            shared = lib.mkOption {
                description = "True if the disk is shared. In this case, bind mounts will be installed";
                type = types.bool;
                default = false;
            };
            fs = lib.mkOption {
                description = "Filesystem type";
                type = types.fsType;
            };
            options = lib.mkOption {
                description = "Mouting options";
                type = types.listOf types.str;
                default = [];
                apply = lib.unique;
            };



        };
    };
    

in

{
    options.naps.volumes.perDirectory = lib.mkOption {
       description  = "Summary of storage allocations across the napsstructure, each directory being referred using an unique deterministic identifier.";
       type = types.attrsOf dirInfos;
       default = {};
    };
    options.naps.volumes.perVM = lib.mkOption {
       description  = "Summary of disks allocated to each VM. Will be of the form disk => vmDisk";
       type = types.attrsOf (types.attrsOf vmDisk);
       default = {};
    };
}
