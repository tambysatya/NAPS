# Configuring the infrastructure topology

## Service Instances

`ServiceInstance` is a basic datastructure describing the context in which a given service lives. Technically, it is a simple association between a unique identifier (referred to as `ServiceID`) and an attrset containing multiple fields. This structure allows NAPS to make a distinction between multiple instances of the same service. ServiceInstances are specified under the `naps.topology.services` options and contain the following fields:

- `naps.topology.services.<name>.is`: this field simply describes which service is declared.

```nix
    is = lib.mkOption {
        description = "What is the service name.";
        type = types.str;
        example = "nextcloud";
    };
```

- `naps.topology.services.<name>.priority`: when multiple instances of the same service are declared, NAPS introduces a mechanism of fallback based on this field.

```nix
    priority = lib.mkOption{
        description = "Max priority is the primary";
        type = types.int;
        default = 100;
    };
```

- `naps.topology.services.tags`. WIP: allows customisation of the service configuration

```nix
    tags = lib.mkOption {
        description = "Specific tags to trigger specific behvavior";
        type = types.listOf (types.oneOf [deployementTag types.str]);
        default = [];
    };
```


- `naps.topology.services.deployement` 

This field is internal: after assigning the service to a virtual machine, NAPS generates a structure summarizing the logical location of the instance.

```nix
    deployement = lib.mkOption {
        description = "Deployement environment of this service";
        type = types.nullOr deployementEnvironment;
        default = null;
    };
```


## Provisioner

A provisioning server must be configured in order to allow NAPS to dispatch the secrets of the infrastructure. Technically, this is a simple HTTP server exposing the secrets using two main ways:

- The first approach relies on single-used tokens that are generated upon VM creation, and passed to the operating system using the sysbios field. This token can be used to generate a specific URL in order to access the secrets. This method is useful to provision the initial secrets of a virtual machine.
- The second approach relies on mutual-TLS: once a virtual machine is created and have access to a TLS certificate, this certificate can be used for authentication in order to get the secrets. This method is useful to deploy or update new secrets on an existing virtual machine.

For this purpose, it is mandatory to specify how to reach the provisioning server in order for NAPS to configure the network of the virtual machines. This done through `naps.topology.provisioner` option, which is an attrset grouping the following fields:

- `naps.topology.provisioner.hostname`: the hostname used by each virtual machine to refer to the provisioner. Note that this hostname *does not need* to be recorded in a DNS, since the network configuration is static and generated upon deployement.

```nix
    hostname = lib.mkOption {
        description = "Hostname of the provisioner, must be reachable by the VMs";
        type = types.str;
        example = "provisioner.local";
        default = "provisioner.${config.naps.topology.domain}";
    };
```
- `naps.topology.provisioner.ips` contains the list of IPs of the provisioning server. Multiple IPs are useful if your infrastructure is deployed within multiple vlans.

```nix
    ips = lib.mkOption {
        description = "Addresses of the provisioning server. It will be used to reach the secrets. This ip can be overrided in each vm configuration.";
        type = types.listOf types.str;
        example = ["192.168.1.200"];
    };
```

- `naps.topology.provisioner.ssh`

In addition to the above options, the secrets-provisioning server can be located on a different machine than the one used to deploy the configuration. NAPS can automatically upload the secrets and configure the service through ssh, if this option is filled. Note that if `lingering` is not enabled on the remote provisioning machine (using `sudo loginctl enable-linger <username>`) to enable persistency of user-defined services, an ssh session should be opened during the entire deployement process.

```nix
    ssh = lib.mkOption {
        description = "If set, the provisioner will run on the specified machine instead of localhost";
        type = types.nullOr types.str;
        example = "naps@192.168.1.151";
        default = null;
    };
```
## Hosts

KVM-hosts need to be declared under `naps.topology.hosts.<name>`. For now, it is only mandatory to specify the IP address.

```nix
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

```
