{flakeRoot, lib, inputs, ...}:
let
    utils = import "${flakeRoot}/lib" {inherit lib inputs;};

    # mount does not likes ":" in names. Therefore, shared persistence is stored under /mnt/point/ins-name/...
    rnameToPath = rname: lib.replaceStrings [":"] ["/"] rname;

    genDisko = {mount, options, filesystem, letter, ...}: {
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

    mkInitDirServices = config: locations: sharedResources: #Initializes the shared volumes (creates the expected directories if they does not exist)
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
                rname: {mode, owner,...}: 
                let
                    disk = config.naps.internal.persistent.ir.resourcesLocation.${rname};
                    persistentPath = "${disk.mount}/${rnameToPath rname}";
                in ''
                    if [[ ! -d ${persistentPath} ]]; then
                        mkdir -p ${persistentPath}
                        chown ${owner} ${persistentPath}
                        chmod ${mode} ${persistentPath}
                    fi
                '';
        in {
            "init-persistent-dirs" = {
                description = "Ensures that bind-mounted and container-mounted directories exist";
                before = reload;
                requiredBy = reload;
                after = mntservices;
                requires = mntservices;
                serviceConfig = {
                    Type = "oneshot";
                    RemainAfterExit = "yes";
                };
                inherit script;
            };
        };

    # Systemd bind-mount
    genMountService  = 
        locations: rname: resource@{reload, path,...}:
        let
            disk = locations.${rname};
            what = "${disk.mount}/${rnameToPath rname}";
            where = path;
        in {
            inherit what where;
            before = reload;
            requiredBy = reload;
            options = "bind";
            type = "none";
        };  
in utils // {
    inherit genDisko genDiskoRoot;
    inherit mkInitDirServices; #initializes shared volumes
    inherit genMountService;  # bind-mount directories
}
