{flakeRoot, lib, inputs, config, pkgs,...}:
let
    utils = import ../lib {inherit lib inputs flakeRoot;};
    initDir = 
        {path, mode, owner,...}: 
        ''
            if [[ ! -d ${path} ]]; then
                mkdir -p ${path}
                chown ${owner} ${path}
                chmod ${mode} ${path}
            fi
        '';
    
    mkInitDirServices = ensuredirs:
        let reload = lib.unique (map (builtins.getAttr "reload") ensuredirs);
            script = lib.concatMapStringsSep "\n" initDir ensuredirs;
            mntservices = lib.unique (map ({mount,...}: utils.pathToMountUnit mount) ensuredirs);
        in {
            "init-persistent-dirs" = {
                description = "Ensures that bind-mounted and container-mounted directories exist";
                before = reload;
                requiredBy = reload;
                after = mntservices;
                requires = mntservices;
                serviceConfig.Type = "oneshot";
                inherit script;
            };
        };

    generateFileSystem = 
        vmname: deploy:
        let 
            /*
            genFS = {letter, mount,fs,options,...}: {
                            ${mount} = {
                                fsType = fs;
                                device = "/dev/vd${letter}";
                                inherit options;
                            };
                    };
            */
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
            genDisko = {letter, mount, options, fs,...}:{
                "vd${letter}" ={
                    device = "/dev/vd${letter}";
                    type = "disk";
                    content = {
                        type = "filesystem";
                        format = fs;
                        mountpoint = mount;
                        mountOptions = options;
                    };
                };
            };
            genMountService  = 
                bind@{reload, ...}: 
                {
                    inherit (bind) what where;
                    before = reload;
                    requiredBy = reload;
                    options = "bind";
                    type = "none";
                };           

            #fileSystems = utils.mergeAll (map genFS deploy.storage.mappings);
            env = deploy.env;
        in {
            ${vmname}.config = {
                #fileSystems = fileSystems;
                #imports = [inputs.disko.nixosModules.disko];
                disko.devices.disk = utils.mergeAll ([genDiskoRoot] ++ map genDisko deploy.storage.mappings);
                systemd.mounts = map genMountService deploy.storage.binds;
                systemd.services = mkInitDirServices deploy.storage.ensureDirs;
            };
        };

    vmDeploys = lib.filterAttrs (_: {env,...}: env.type == "vm") config.infra.deploy.systems; # Only VMs configure the filesystems, not the containers
in{
    config.infra.outputs.systems = utils.mergeAll (lib.mapAttrsToList generateFileSystem vmDeploys); 
}
