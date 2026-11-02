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
            internal = true;
            type = types.nullOr types.deployementEnvironment;
            default = null;
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
            default = "/srv/persistent";
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
        letter = lib.mkOption {
            description = "Letter X in vdX: name of the device in the VM side";
            type = types.nullOr types.str;
            default = null; #set during assignment
            internal = true;

        };
    };
};

/* A persistent resource, which is migrable and backupable and that is referred to using a unique identifierw*/
resource = types.submodule {
    options = {
        path = lib.mkOption {
            description = "Path of the persistent directory";
            internal = true;
            type = types.nullOr types.str; # set when the resource identifier is assigned
            default = null;
        };
        instance = lib.mkOption {
            description = "Instance requesting this resource";
            internal = true;
            type = types.nullOr types.serviceInstance;
            default = null; # set when the resource identifier is assigned
        };
        shareable = lib.mkOption {
            description = "True if this directory can be stored on a shared disk"; 
            type = types.bool;
            default = false;
        };
        mode = types.dirmode;
        inherit (types) owner group reload;
    };
};


}
