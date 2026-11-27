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
- `naps.topology.services.<name>.config`. WIP: allows customisation of the service configuration

```nix
    config = lib.mkOption {
        description = "The extra-configuration module merged with the system configuration";
        type = types.deferredModule;
        default = {config, ...}:{};
    };
```

- `naps.topology.services.<name>.tags`. WIP: allows customisation of the service configuration (interactions with NAPS)

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

In addition to the above options, the secrets-provisioning server can be located on a different machine than the one used to deploy the configuration. NAPS can automatically upload the secrets and configure the service through ssh, if this option is filled. 
::: {.important}
Note that if `lingering` is not enabled on the remote provisioning machine to allow persistency of user-defined services, an ssh session should be opened during the entire deployement process. 

`lingering` can ben enabled using `sudo loginctl enable-linger <username>`.
:::

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

## Virtual machines

Finally, the configuration of the virtual machines is the core of the declaration of the infrastructure. Obvious fields are the `host`, the number of `vcpu`, the allocated `memory` and the static `ip` address. Services instances running natively are declared under the `service` option while services runing within nixos-containers are declared under `containers`.

In addition of this, some services may request data-persistency. For instance, the following code declaring a virtual machine running nextcloud will not evaluate:

```nix
 naps.topology.services = {
    nc-main = {is = "nextcloud";};
 };
 naps.topology.vms.apps = {
        host = "cpuhost1";
        vcpu = 8;
        memory = 16000;
        ip = "10.0.0.53";
        containers = ["nc-main"]; 
 };
```
and an error will be raised:
```
error: No persistent volume for resource nc-main:/var/lib/nextcloud/data on apps. Either assign a dedicated volume on apps or enable sharing.

```

This means that the nextcloud has requested that `/var/lib/nextcloud/data` should be persistent and it is thus mandatory to mention where to store this resource. Therefore, a dedicated partition should be created on the host (`cpuhost1` in the example).

```nix
 naps.topology.vms.apps = {
        host = "cpuhost1";
        vcpu = 8;
        memory = 16000;
        ip = "10.0.0.53";
        containers = ["nc-main"]; 
        disks = [
            {type="disk"; location="/dev/mapper/nextcloud-persistent-data"; mount="/var/lib/nextcloud/data"; filesystem="xfs"; options=["noatime"];}
        ];
};
```

Note that nextcloud additionaly requests `/var/lib/nextcloud/config` to be persistent as well. However, declaring an entire partition for each small directory might be painful. Therefore, NAPS provides a way to specify that a disk can be `shared` to store the persistent datas of multiple files. For instance, since nextcloud uses the centralized postgres database and the S3 storage for storing the datas, `/var/lib/nextcloud/data` and `/var/lib/nextcloud/config` only contain text configuration files in practice. Similarily, forgajo (a code forge) behave similarily. It is then possible to store both configs on the same partition by enabling sharing using the flag `shared=true`:

```nix
 naps.topology.vms.apps = {
        host = "cpuhost1";
        vcpu = 8;
        memory = 16000;

        ip = "10.0.0.53";
        containers = ["nc-main" "git-main"]; 
        disks = [
            {type="qcow"; location="persistent"; filesystem="ext4"; shared=true; options = ["nofail"];}
        ];
      };
```

The code above generates a qcow image that will be shared between the different services requiring persistency of their data. Note that some services can explicitely forbid the use of sharing (e.g. when the amount of data to be stored is huge). For instance, the following code, deploying a postgres database, will not evaluate:
```nix
 naps.topology.services = {
    pg-main = {is = "postgres";};
 };
 naps.topology.vms.postgres = {
        host = "cpuhost1";
        vcpu = 4;
        memory = 8000;
        ip = "10.0.0.52";
        services = ["pg-main"]; 
      };
```
and will raise the following error:
```
error: No persistent volume for resource pg-main:/var/lib/postgresql on postgres. This resource REQUIRES an individual volume
```

Setting a disk with `shared=false` fixes the problem.

## Deployement of the configuration

Running `naps apply` should do the work. It will sequentially:

- generate the secrets
- upload the secrets on the provisioning server (if `naps.topology.provisioner.ssh` is set)
- generate the terraform virtual machines configurations (using `terranix`)
- generate single-use tokens and pass them to each vitual machine via the `smbios` field
- generate a self-installable bootable iso
- deploy the virtual machines
