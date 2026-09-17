{flakeRoot, lib, inputs, ...}:
let 
    libtypes = lib.types;
    mytypes = import "${flakeRoot}/lib/types" {inherit lib inputs;};
    types = libtypes // mytypes;
in
{
    /* Virtual machine description */
    vmConf = lib.types.submodule {
        options = {
            host = lib.mkOption {
              type = types.str;
              description = "The host where the the VM will be created";
            };
            bridge = lib.mkOption {
              type = types.str;
              description = "Network bridge on which the VM will be attached";
              default = "br0";
            };
            vcpu = lib.mkOption {
              type = types.ints.unsigned;
              description = "The number of vCPUS allocated to the VM";
              default = 1;
            };
            memory = lib.mkOption {
              type = types.ints.unsigned;
              description = "The size of the memory (MiB) allocated to the VM";
              default = 1024;
            };
            disks = lib.mkOption {
              type = types.listOf types.disk;
              description = "Additional volumes that will be passed to the VM";
              default = [];
            };
            ip = lib.mkOption { 
              type = types.str;
              description = "The IP address of the VM";
            };
            services = lib.mkOption {
              type = types.listOf types.str;  
              description = "List of services identifier deployed on the VM";
              example = ["openldap-main"]; #TODO check if they are declared
              default = [];
            };
            containers = lib.mkOption {
              type = types.listOf types.str;
              description = "List of services identifier deployed inside a container VM";
              example = ["ldap"];
              default = [];
            };
            centralizeLogs = lib.mkOption {
                description = "Logs of this machine should be centralized using journald-upload/journald-remote"; 
                type = types.bool;
                default = true;
            };

            /*
            test = lib.mkOption {
                type = types.bool;
                description = "The machine is used for tests and will belong to a specific zone";
                default = false;
            };
            */
          };
        };


}
