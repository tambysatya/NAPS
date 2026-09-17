{inputs, lib,...}:

let 
    napstypes = import "${inputs.self.outPath}/lib/naps/types.nix" {inherit lib;};
    regtypes = import "${inputs.self.outPath}/lib/registry/types" {inherit lib;};
    types = lib.types // napstypes // regtypes;;

    attachedVolume = types.submodule {
        options = {
            hostDevice = lib.mkOption {
                description = "Device on the host (bare-metal) server";
                type = types.str;
                example = "/dev/sda1";
            };
            vmDevice = lib.mkOption {
                description = "Device on the vm.";
                type = types.str;
                example = "vdb";
            };
            options = lib.mkOption {
                description = "List of mounting options";
                type = types.listOf types.str;
                default = [];
                example = ["nofail"];
            };
            fsType = lib.mkOption {
                description = "Filesystem";
                type = types.fsType;
            };
            deviceType = lib.mkOption {
                description = "Type of device";
                type = types.enum ["disk" "qcow"];
            };
        };
    };
    persistentDirectories = types.submodule {
        options = {
            srcMountDir = lib.mkOption {
                description = "Mountpoint";
                type = types.str;
                example = "/mnt/volume";
            };
            srcPath = lib.mkOption {
                description = "Location on the volume";
                type = types.str;
                example = "/mnt/volume/dir";
            };
            owner = lib.mkOption {
                description = "Owner of the directory";
                type = types.str;
            };
            mode = lib.mkOption {
                description = "Mounting permissions";
                type = types.str;
                default = "0700";
            };
            reload = lib.mkOption {
                description = "List of services using this directory";
                type = types.listOf types.str;
                default = [];
            };
            deployement = lib.mkOption {
                description = "Describes how the directory should be deployed";
                type = types.enum ["container" "native"];
            };
            service = lib.mkOption {
                description = "Name of the service requesting this resource";
                type = napstypes.serviceType;
            };
        };
    };
    
in

{
    vmConfig = types.submodule {
        options = {
            attachedVolumes = lib.mkOption {
                description = "Disks attached to the VM";
                type = types.attrsOf attachedVolume ; # mountpoints -> mountoptions
                example = {"/srv/data" = {hostDevice = "/dev/sda1"; vmDevice = "vdb"; options = ["nofail"];};};
                default = {};
            };
            persistentDirectories = lib.mkOption {
                description = "Directory stored on an external volume";
                type = types.attrsOf persistentDir; # requestedFile => Informations
                default = {};
            };
        };
    };
}
    
