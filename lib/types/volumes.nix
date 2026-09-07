{lib, inputs,...}:
let
types = lib.types // import ./files.nix {inherit lib;} // import ./deployement.nix {inherit lib inputs;};
fsType = lib.types.enum ["xfs" "ext4" "ntfs"];


in
{

inherit fsType;

volume = types.submodule { # Persistent volumes
    options = {
        owner = lib.mkOption {
            description = "Owner of the directory";
            type = types.str;
            default = "root";
        };
        path = lib.mkOption {
            description = "Path of the persistent directory";
            type = types.str;
            example = "/var/lib/docker/storage";
        };
        reload = lib.mkOption {
            description = "Services that requires the volume.";
            type = types.listOf types.str;
            default = [];
        };
        mode = lib.mkOption {
            description = "Permissions of the directory";
            type = types.str;
            default = "0700";
        };
        shared = lib.mkOption {
            description = "If true, multiple services registering 'shared' directories can store their data.";
            type = types.bool;
            default = false;
        };
    };
};

disk = types.submodule {
    options= {
        path = lib.mkOption {
            description = "name of the qcow disk or path to the device block";
            type = types.str;
        };
        mount = lib.mkOption {
            description = "Mounting point. If set to null, the directory will be mounted on /srv/<name>";
            type = types.nullOr types.str;
            default = null;
        };
        type = lib.mkOption {
            description = "If the disk is a qcow volume or a raw disk";
            type = types.enum ["qcow" "disk"];
        };
        size = lib.mkOption {
            description = "Size of the qcow disk. This option is ignored if type='disk'";
            type = types.ints.positive;
            default = 1024*1024*100; #100M
        };
        shared = lib.mkOption {
            description = "This volume will be shared by multiple services";
            type = types.bool;
            default = false;
        };
        fs = lib.mkOption {
            description = "Filesystem format";
            type = fsType;
            default = "ext4";
        };
        options = lib.mkOption {
            description = "Mounting options";
            type = types.listOf types.str;
            default = ["nofail"];
        };
    };
};

directory = types.submodule {
    options = {
        path = types.filename;
        mode = types.dirmode;
        inherit (types) owner reload;
        env = lib.mkOption {
            description = "Which environment requests the directory";
            type = types.deployementEnvironment;
        };
        mount = lib.mkOption {
            description = "Mountpoint where the directory is supposed to exists";
            type = types.str;
        };
    };
};

}
