{flakeRoot, lib, inputs, pkgs, config, ...}:

let
    libtypes = lib.types;
    infratypes = import "${flakeRoot}/lib/types" {inherit lib inputs;};
    types = libtypes // infratypes;

    secretFile = types.submodule {
        options = {
            inherit (types) filename owner;
            mode = types.filemode;
        };
    };

    diskMapping = types.submodule {
        options = {
            type = lib.mkOption {
                description = "Type of storage";
                type = types.enum ["qcow" "disk"];
            };
            host = lib.mkOption {
                description = "Path to the disk on the host";
                type = types.str;
            };
            letter = lib.mkOption {
                description = "Letter corresponding to the device mapping vdX";
                type = types.str;
            };
            mount = lib.mkOption {
                description = "Where to mount the disk";
                type = types.str;
            };
            fs = lib.mkOption {
                description = "Filesystem type";
                type = types.fsType;
            };
            options = lib.mkOption {
                description = "Mounting options";
                type = types.listOf types.str;
                default = [];
                apply = lib.unique;
            };

        };  
    };

    bindMount = types.submodule {
        options = {
            what = lib.mkOption {
                description = "Source directory (what to mount). The directory will be created if it does not exists.";
                type = types.str;
            };
            where = lib.mkOption {
                description = "Target directory (where to mount).";
                type = types.str;
            };
            inherit (types) owner reload;
            mode = types.dirmode; 
        };
    };
    containerMount = types.submodule {
        options = {
            hostPath = lib.mkOption {
                description = "Path of the directory on the host";
                type = types.str;
            };
            isReadOnly = lib.mkOption {
                description = "If set to read-only";
                type = types.bool;
                default = false;
            };
            inherit (types) owner reload;
            mode = types.dirmode;

        };
    };

    storage = types.submodule {
        options = {
            mappings = lib.mkOption {
                description = "Mapping between disks on the KVM host and on the virtual machine";
                type = types.listOf diskMapping;
                default = [];
            };
            binds = lib.mkOption {
                description = "Bind mounted directories.";
                type = types.listOf bindMount;
                default = [];
            };
            containers = lib.mkOption {
                description = "Bind mounted directories through the containers. For each container, there is an attrset filename => {hostpath}";
                type = types.attrsOf (types.attrsOf containerMount);
                default = {};
            };
            ensureDirs = lib.mkOption {
                description = "Directory that need to be created if they don't exist";
                type = types.listOf types.directory;
                default = [];

            };
        };
    };

    deployementConfig = types.submodule {
        options = {
            env = lib.mkOption {
                description = "This system is a VM or a container";
                type = types.deployementEnvironment;
            };
            ip = lib.mkOption {
                description = "IP address";
                type = types.str;
            };
            users = lib.mkOption {
                description = "List of service users to be created";
                type = types.listOf types.user;
                default = [];
            };
            secrets = lib.mkOption {
                description = "All secrets files.";
                type = types.listOf secretFile;
                default = [];
            };
            sslCertificates = lib.mkOption {
                description = "All SSL certificates to refresh";
                type = types.listOf types.sslCertificate;
                default = [];
            };
            proxy = lib.mkOption {
                description = "Network interactions";    
                type = proxy;
            };
            storage = lib.mkOption {
                description = "Persistent storage  configuration";
                type = storage;
            };

        };
    };

    addr = types.submodule {
        options = {
            inherit (types) ip port;
        };  
    };
    backend = types.submodule {
        options = {
            inherit (types) ip port;
            env = lib.mkOption {
                description = "Where the backend is deployed";
                type = types.deployementEnvironment;
            };
        };
    };

    httpProxyEntry = types.submodule {
        options = {
            backends = lib.mkOption {
                description = "List of backends, ordered by priority";
                type = types.listOf backend;
                default = [];
            };
            tls = lib.mkOption {
                description = "If set to true, the HA proxy terminates TLS: a certificate will be generated automatically";
                type = types.bool;
                default = false;
            };
            extraConfig = lib.mkOption {
                description = "Extra option passed to the proxy";
                type = types.attrs;
                default = {};
            };
        };
    };
    proxyEntry = types.submodule {
        options = {
            frontend = lib.mkOption {
                description = "Listening server";
                type = addr;
            };
            backends = lib.mkOption {
                description = "List of backends, ordered by priority";
                type = types.listOf backend;
                default = [];
            };
            extraConfig = lib.mkOption {
                description = "Extra option passed to the proxy";
                type = types.attrs;
                default = {};
            };
        };
    };

    proxy = types.submodule {
        options = {
            tcp = lib.mkOption {
                description = "Correspondances name => frontend/backend";
                type = types.attrsOf proxyEntry;
                default = {};
            };
            udp = lib.mkOption {
                description = "Correspondances name => frontend/backend";
                type = types.attrsOf proxyEntry;
                default = {};
            };
            http = lib.mkOption {
                description = "Correspondances VirtualHost => [backend]";
                type = types.attrsOf httpProxyEntry;
                default = {};
            };
        };
    };

    location = types.submodule {
        options = {
            env = lib.mkOption {
                description = "Environment of the server";
                type = types.deployementEnvironment;
            };
            inherit (types) port;

        };
    };

    endpointEntry = types.submodule {
        options = {
            env = lib.mkOption {
                description = "Which environment runs the endpoint";
                type = types.deployementEnvironment;
            };
            inherit (types) port;
        };
    };
        
in
{
    options.infra.deploy.systems = lib.mkOption {
        internal = true;
        description = "Intermediate representation of a virtual machine configuration";
        type = types.attrsOf deployementConfig;
    };
    options.infra.deploy.endpoints = lib.mkOption {
        internal = true;
        description = "Intermediate representation of the entire network.";
        type = types.attrsOf (types.listOf endpointEntry); # domainname => [env]
    };
    options.infra.deploy.users = lib.mkOption {
        internal = true;
        description = "UserID mappings";
        type = types.listOf types.user;
        default = [];
    };

}
