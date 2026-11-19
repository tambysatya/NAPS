# Configuring the infrastructure topology

## Service Instances

`ServiceInstance` is a basic datastructure describing the context in which a given service lives. Technically, it is a simple association between a unique identifier (referred to as `ServiceID`) and an attrset containing multiple fields. This structure allows NAPS to make a distinction between multiple instances of the same service.

```nix
    is = lib.mkOption {
        description = "What is the service name.";
        type = types.str;
        example = "nextcloud";
    };
```

This field simply describes which service is declared.

```nix
    priority = lib.mkOption{
        description = "Max priority is the primary";
        type = types.int;
        default = 100;
    };
```

When multiple instances of the same service are declared, NAPS introduces a mechanism of fallback based on this field.

```nix
    tags = lib.mkOption {
        description = "Specific tags to trigger specific behvavior";
        type = types.listOf (types.oneOf [deployementTag types.str]);
        default = [];
    };
```

WIP: allows customisation of the service configuration


```nix
    deployement = lib.mkOption {
        description = "Deployement environment of this service";
        type = types.nullOr deployementEnvironment;
        default = null;
    };
```

This field is internal: after assigning the service to a virtual machine, NAPS generates a structure summarizing the logical location of the instance.

## Provisioner

A provisioning server must be configured in order to allow NAPS to dispatch the secrets of the infrastructure. Technically, this is a simple HTTP server exposing the secrets using two main ways:

- The first approach relies on single-used tokens that are generated upon VM creation, and passed to the operating system using the sysbios field. This token can be used to generate a specific URL in order to access the secrets. This method is useful to provision the initial secrets of a virtual machine.
- The second approach relies on mutual-TLS: once a virtual machine is created and have access to a TLS certificate, this certificate can be used for authentication in order to get the secrets. This method is useful to deploy or update new secrets on an existing virtual machine.

```nix
    provisioner = types.submodule {
        options = {
            hostname = lib.mkOption {
                description = "Hostname of the provisioner, must be reachable by the VMs";
                type = types.str;
                example = "provisioner.local";
                default = "provisioner.${config.naps.topology.domain}";
            };
            ips = lib.mkOption {
                description = "Addresses of the provisioning server. It will be used to reach the secrets. This ip can be overrided in each vm configuration.";
                type = types.listOf types.str;
                example = "192.168.1.200";
            };
            ssh = lib.mkOption {
                description = "If set, the provisioner will run on the specified machine instead of localhost";
                type = types.nullOr types.str;
                example = "naps@192.168.1.151";
                default = null;
            };
        };
    };
```
## Hosts
