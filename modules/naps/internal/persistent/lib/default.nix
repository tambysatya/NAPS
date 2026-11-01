{flakeRoot, lib, inputs, ...}:
let
    utils = import "${flakeRoot}/lib" {inherit lib inputs;};
    genDisko = {mount, options, filesystem,...}: letter: {
        "vd${letter}" ={
            device = "/dev/vd${letter}";
            type = "disk";
            content = {
                type = "filesystem";
                format = filesystem;
                mountpoint = mount;
                mountOptions = options;
            };
        };
    };
    genDiskoRoot = {
        vda = {
            type = "disk";
            device = "/dev/vda";
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
    };

in utils // {
    inherit genDisko genDiskoRoot;
}
