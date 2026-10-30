{lib, inputs,...}:
let
types = lib.types // import ./files.nix {inherit lib inputs;} // import ./deployement.nix {inherit lib inputs;};
fsType = lib.types.enum ["xfs" "ext4" "ntfs"];


in
rec {

inherit fsType;

/* 
    Physical disk, associated to a VM.
    Identified using a unique identifier: envuid:diskname
*/
disk = types.submodule {
    options = {
        env = lib.mkOption {
            description = "Deployement environment possessing the disk";
            type = types.deployementEnvironment;
        };
        type = lib.mkOption {
            description = "Type of kvm storage";
            type = types.enum ["qcow" "disk"];
        };
        location = lib.mkOption {
            description = "Physical location, on the KVM host. Can be a path to a dev block or a path to a qcow file";
            type = types.str;
            example = "/dev/sda1";
        };
        mount = lib.mkOption {
            description = "Mount point on the VM";
            type = types.str;
            example = "/srv/persistent";
        };
        filesystem = lib.mkOption {
            description = "Filesystem type";
            type = fsType;
        };
        options = lib.mkOption {
            description = "Mounting options";
            type = types.listOf types.str;
            default = [];
        };
        shared = lib.mkOption {
            description = "True if this disk can contain multiple resources";
            type = types.bool;
            default = false;
        };
    };
};

/* Logical information on the directory (owner, permissions, bindmount,...) */
logInfos = types.submodule {
    options = {
        mode = types.fileMode;
        inherit (types) owner group reload;
        bind = lib.mkOption {
            description = "Path where the resource should be bind-mounted (facultative)";
            type = types.nullOr types.str;
            example = "/var/lib/persistent/logs";
        };
    };
};

/* A persistent resource, which is migrable and backupable and that is referred to using a unique identifierw*/
resource = types.submodule {
        instance = lib.mkOption {
            description = "Instance requesting the resource"; 
            type = types.serviceInstance;
        };
        phys = lib.mkOption {
            description = "Identifier of the kvm disk";
            type = types.str;
        };
        backupArgs = lib.mkOption {
            description = "Arguments to generate the backup script [UNUSED]";
            type = types.attrs;
        };
        migrateArgs = lib.mkOption {
            description = "Arguments to generate the migration script [UNUSED]";
            type = types.attrs;
        };
};


}
