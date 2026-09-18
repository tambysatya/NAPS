{flakeRoot, inputs, lib, config, ... }:

let
    libtypes = lib.types;
    vmtypes = import ./vms.nix {inherit flakeRoot lib inputs config;};
    mytypes = import "${flakeRoot}/lib/types" { inherit lib inputs;};
    types = libtypes // vmtypes // mytypes;
     /* Options definitions */
    serviceIdentity = types.submodule {
        options = {
            is = lib.mkOption {
                description = "Name of the service";
                type = types.str;
            };
            priority = lib.mkOption {
                description = "Max priority is the primary service";
                type = types.int;
                default = 100;
            };
            tags = lib.mkOption {
                description = "Tags to trigger specific behavior";
                type = types.listOf (types.oneOf [types.deployementTag types.str]);
                default = [];
            };
        };
    };

    topology = types.submodule {
        options = {
            provisionerHost = lib.mkOption {
                description = "Address of the provisioning server. It will be used to reach the secrets.";
                type = types.str;
                example = "provisioner.local";
                default = "provisioner.${config.naps.topology.domain}";
            };
            provisionerAddr = lib.mkOption {
                description = "Default Address of the provisioning server. It will be used to reach the secrets.";
                type = types.str;
                example = "192.168.1.200";
            };
            domain = lib.mkOption {
                description = "Domain of the napsstructure";
                type = types.str;
                example = "naps.local";
            };
            services = lib.mkOption {
                description = "All services instances, referenced using an unique identifier. Required to handle migrations.";
                type = types.attrsOf serviceIdentity;
                default = {};
            };

            vmSubnet = lib.mkOption {
                type = types.str;
                example = "10.0.1.0/24";
                description = "Subnet of the vlan";
            };

            dns = lib.mkOption {
              description = "Domain Name Servers of the napsstructure";
              type = types.listOf types.str;
              example = ["8.8.8.8" "8.8.4.4"];
            };
            gateway = lib.mkOption {
              type = types.str;
              description = "Address of the gateway for the default route";
            };
            rootSSHPublicKeys = lib.mkOption {
              type = types.listOf types.str;
              description = "A list of SSH keys that will be allowed to connect as root";
            };
            hosts = lib.mkOption {
              description = "Available baremetal hosts";
              type = types.attrsOf (
                types.submodule {
                  options = {
                    ipAddress = lib.mkOption {description = "IP address of the host"; type = types.str;};
                  };
                }
              );
            };
            vms = lib.mkOption {
              description = "Configuration of the virtual machines";
              type = types.attrsOf types.vmConf;
            };
        };
      };


in
{
   options.naps.topology = lib.mkOption {
        description = "Topology of the napsstructure";
        type = topology;
   };

}
