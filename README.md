


# NAPS: Nix-based Automated Plumbing System

![With NAPS, enjoy more naps !](./images/naps.png)

Status: WIP, experimental

Features: 

- declarative and reproducible deployement using NixOS
- automated generation of secrets (services passwords, databases access...) from the infrastructure inventory
- clear separation between systems and data: systems can be safely destroyed without risking any data loss
- automatic virtual machines generation and configuration using Open Tofu
- automatic generation of reverse-proxys with TLS enabled
- automatic generation of systemd services in order to integrate dependencies between services across the infrastructure (WIP)
- simple API to integrates more services: simply declares the passwords, ssl certificates, and endpoints: everything will be automatically generated.

see `examples/` 

## Try

```
    nix flake new -t github:tambysatya/NAPS my-infra/
```

## Compilation:

Each service declares the resources it needs (secrets, endpoints, postgres bases...). The compilation is split into two phases.

- During the first phase, the compiler summarizes the resources requirements of each services over the infrastructure
- During the second phase, the resources are allocated, e.g. reverse proxys / pNAT rules are built (depending on the type of endpoint), users and secrets are created (if the services is runned inside a container)...
- 
## Warning:

Some passwords (e.g. the keycloak initial password) are necessarily world readable. This means that the password will live in `/nix/store`. Moreover, if the flake is evaluated purely, the password must be part of the git (this is why `gen-secrets` puts it in .secrets/git). Therefore, some passwords **must** be changed (i) fast (ii) before any commit. 

## Code Architecture:

Main module: config.infra

- infra.topology : description of the infrastructure (filled during the deployement)
- infra.services.name : API for services to register what are their needs
- ... others are internal structures which are essentially views of the infrastructure to simplify secret generation, visualization, coherence verification...

# TODO


- step-renew increase the refresh rate
- step-renew: use a service user instead of root

- network config in infra + regroup the options by theme 



- persistence of datas: Two independent tofu states: compute state (destroyable) and storage state (persistent)


- TODO tests (config works + secrets exists + secrets are properly encrypted + no clash between users)


- hydra: use S3 cache ?

- users: some usersID are set by their own service. Now we FORCE it to a new value (our) but not sure if this is a good approach TODO

- Services: maybe services/default.nix should contain the registration and servicse/config.nix the content ?? 

- GARAGE: adjust the snapshot interval




Deployement:
- curent refactor involved deployement options (like priority), but VMs may also have tags (like testing, backup) that is applied to their services

-TODO: add flakes templates for users

Migration:
- store the current state in a JSON
- add an ID to each service of the infra
- generate unique IDs from persistent resources from the ID of the service requiring it
- generate a migration script from the current state and the desired state


- Assume that there is only one shared volume per VM: therefore there is no need to declare it in the inventory, except maybe to change the default size

- TODO: stores the TLS certificates rootca + interùmediate ca in the nix store to ensure a pure reproducible behavior
- EXTEND: put the secrets in the store of the provisioning machine ?

- TODO:  the iso should use the network config of the vm it tries to install (to avoid requiring a dhcp)
 
### Refactor

- naps.secrets:  
    + sslCertificates are processed both in naps.deploy.store AND in modules.naps.secrets  (for the reverseProxy) which is confusing
    + currently, naps.secrets depends on naps.services => should depend on naps.deploy.systems
    + maybe use something more simple for the secrets: a type FILES just a type and an installation path + extra arguments
    + implements constructors to create serets declaration (mkS3Secrets, mkDBSecrets...)
    + gen-secrets implements the generation based on the type using the extra args
    + install-secrets implements the installation based on the type using the extra args
- NAPS application: 
    + allows either to deploy a VM or to "update" a VM (without tofu) - using rebuils / ssh for the secrets
    + write a script that uploads the secrets to the provisioner using ssh and launch the secret provisioner automatically (based on the topology description)


### Late game project

- write a tool that deploys only the vm that have changed
- maybe deploy a static provisioning server to give new secrets or change secrets dynamically to the vm. EG a new vm is created, requesting postgres, it could be great that postgres have a daemon listenning to the provisioning server, and updates its database (creates new key) dynamically without having to redeploy it


### Prio

- Use UserID instead of proper user creation (for the secrets and files within the containers)
- containerMount non-shared persistent volumes
- haproxy: handle both tls termination + passthrough (https://pastebin.com/pkRsp9cc)
- config: use deploy.<name>.reverseProxy and deploy.<name>.proxy to handle clearly both directions of the proxy and resolves conflicts ?
- instead of working in domain (local.fr) create a subdomain like (naps.local.fr) to ensure no clash with existing installation
- params the ip address of the containers private network (actually its forced to be 192.168.100.0/24) 
- integrate full chain in the certificates and only pass root_ca.crt (not intermediate_ca.crt) (WIP)
- deploy: being able to deploy new machines withotu destroying the others 
- containers: BRIDGE all the interfaces for the vm to allow haproxy to listen simultaneously for all containers ?TODO
- containers: BLOCK routing between two containers (is it possible ? probably in netfilter)
- LISTENING: servers should listen on 127.0.0.1 if they are running natively; but on 0.0.0.0 if they are run within a container
- FIREWALL: ports should be oppened only if the service runs within a container (and firewall should be handled by the service)
- iso: use different iso names (otherwise tofu does not upload it)
- S3: links: check if a bucket key exists and replace if with the new one
- step: use a single-use token instead of a certificate ?
- include the secret provisioner in NAPS
- lifecycle: tofu must ignore the smbios parameters
- nix: run garbage collector every xxx days to save space ?


### IDEAS

- add a "why" option in the persistent directory declaration in register to add a message describing why the repository is useful whenever the user does not declare it. E.G "/nix: used for hydra to cache builds. Should be consequent enough to handle multiple versions of the same project"


CHECKS:
- check that each disk is declared once
- each disk is mounted on ONE mountpoint
- each mountpoint is declared by one disk
- Two services does not request the same repository
- checks if the partitions exist on the KVM hosts 
- centralizeLogs cannot be enabled if journald-remote is not deployed
- Two services are not listening simultaneously on the same port (at least on the same system)


EXPERIMENTS:
- check multiple containers running on the same VM
