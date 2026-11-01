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


 
 /*
    mkInitDirServices = ensuredirs: #Initializes the shared volumes (creates the expected directories if they does not exist)
        let reload = lib.unique 
                        (lib.concatMap 
                            (dir@{env,reload,...}: 
                                if env.type == "vm" then reload
                                else if env.type == "container" then ["container@${utils.envUID env}.service"]
                                else throw "mkInitDir: not implementend for deployement type ${env.type}")
                         ensuredirs);
            script = lib.concatMapStringsSep "\n" initDir ensuredirs;
            mntservices = lib.unique (map ({mount,...}: utils.pathToMountUnit mount) ensuredirs);
            initDir = 
                {path, mode, owner,...}: 
                ''
                    if [[ ! -d ${path} ]]; then
                        mkdir -p ${path}
                        chown ${owner} ${path}
                        chmod ${mode} ${path}
                    fi
                '';
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

    */  
    mkInitDirServices = locations: sharedResources: #Initializes the shared volumes (creates the expected directories if they does not exist)
        let reload = lib.unique 
                        (lib.concatMap 
                            (resource@{instance,reload,...}: 
                                if utils.runsInVM instance then reload
                                else if utils.runsInContainer instance then ["container@${utils.insEnvUID instance}.service"]
                                else throw "mkInitDir: not implementend for deployement type ${(utils.insEnv instance).type}")
                         (builtins.attrValues sharedResources));
            script = utils.concatMapAttrsStringsSep "\n" initDir sharedResources;
            mntservices = lib.unique (lib.mapAttrsToList (rname: _: utils.pathToMountUnit locations.${rname}.mount) sharedResources);
            initDir = 
                rname: {path, mode, owner,...}: 
                ''
                    if [[ ! -d ${path} ]]; then
                        mkdir -p ${path}
                        chown ${owner} ${path}
                        chmod ${mode} ${path}
                    fi
                '';
        in {
            systemd.services."init-persistent-dirs" = {
                description = "Ensures that bind-mounted and container-mounted directories exist";
                before = reload;
                requiredBy = reload;
                after = mntservices;
                requires = mntservices;
                serviceConfig.Type = "oneshot";
                inherit script;
            };
        };
in utils // {
    inherit genDisko genDiskoRoot;
    inherit mkInitDirServices;
}
