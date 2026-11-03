{flakeRoot, lib, inputs, config,...}:

let
    libtypes = import "${flakeRoot}/lib/types" {inherit lib inputs;};
    types = lib.types // libtypes;

    diskUID = types.str;
    resourceUID = types.str;

    attachmentsInfos = types.submodule {
        options = {
            disks = lib.mkOption {
                description = "The set of disks attached to an environment. Map DiskUID Disk";
                type = types.attrsOf types.disk;
                default = {};
            };
            resources = lib.mkOption {
                description = "The set of resources attached to an environment. Map ResourceUID Resource";
                type = types.attrsOf types.resource;
                default = {};
            };
        };
    };
    attachments = types.submodule {
        options = {
            perEnv= lib.mkOption {
                description = "Attachments sorted per Environment: Map EnvUID Attachments";
                type = types.attrsOf attachmentsInfos;
                default = {};
            };
            perVM = lib.mkOption {
                description = "Attachment groupped per VM: Map VMuid Attachments";
                type = types.attrsOf attachmentsInfos;
                default = {};
            };
        };
    };
    ir = types.submodule {
        options = {
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
            attachments = lib.mkOption {
                description = "The set of disks attached to an environment";
                type = attachments;
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
    options.naps.internal.persistent.outputs = lib.mkOption {
       description  = "All configurations";
       type = types.attrsOf types.config;
       default = {};
    };
}
