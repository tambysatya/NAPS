{flakeRoot, lib, inputs, config,...}:

let
    libtypes = import "${flakeRoot}/lib/types" {inherit lib inputs;};
    types = lib.types // libtypes;

    diskUID = types.str;
    resourceUID = types.str;

    ir = types.submodule {
        options = {
            attachments = lib.mkOption {
                description = "The set of disks attached to an environment. Map EnvUID (Map DiskUID Disk)";
                type = types.attrsOf (types.attrsOf types.disk);
                default = {};
            };
            disks = lib.mkOption {
                description = "The set of ressources assigned on a disk: Map DiskUID (Map ResourceUID Resource)";
                type = types.attrsOf (types.attrsOf types.resource);
                default = {};
            };
            resourcesLocation = lib.mkOption {
                description = "The disk on which each resource lives: Map ResourceUID Disk";
                type = types.attrsOf types.disk;
                default = {};
            };
        };
    };

in

{
    options.naps.internal.persistent.disks= lib.mkOption {
       description  = "All KVM disks, indexed using their unique identifier: Map DiskUID Disk";
       type = types.attrsOf types.disk;
       default = {};
    };
    options.naps.internal.persistent.resources = lib.mkOption {
       description  = "All resources, indexed using their unique identifier: Map ResourceID Disk";
       type = types.attrsOf types.resource;
       default = {};
    };
    options.naps.internal.persistent.ir = lib.mkOption {
       description  = "All resources assignment";
       type = ir;
       default = {};
    };
}
