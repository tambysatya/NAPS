


# Small-lab: automated and reproducible deployement of services.

Features: 

- declarative and reproducible deployement using NixOS
- automated generation of secrets (services passwords, databases access...) from the infrastructure inventory
- clear separation between systems and data: systems can be safely destroyed without risking any data loss
- automatic virtual machines generation and configuration using Open Tofu
- automatic generation of reverse-proxys with TLS enabled
- automatic generation of systemd services in order to integrate dependencies between services across the infrastructure (WIP)
- simple API to integrates more services: simply declares the passwords, ssl certificates, and endpoints: everything will be automatically generated.

see `examples/` 

## Compilation:

Each service declares the resources it needs (secrets, endpoints, postgres bases...). The compilation is split into two phases.

- During the first phase, the compiler summarizes the resources requirements of each services over the infrastructure
- During the second phase, the resources are allocated, e.g. reverse proxys / pNAT rules are built (depending on the type of endpoint), users and secrets are created (if the services is runned inside a container)...

## Code Architecture:

Main module: config.infra

- infra.topology : description of the infrastructure (filled during the deployement)
- infra.services.name : API for services to register what are their needs
- ... others are internal structures which are essentially views of the infrastructure to simplify secret generation, visualization, coherence verification...

# TODO

- custom service config should be decided in "infra.services" in order to avoid infinite recursion

- step-renew increase the refresh rate
- step-renew: use a service user instead of root

- network config in infra + regroup the options by theme 



- persistence of datas: Two independent tofu states: compute state (destroyable) and storage state (persistent)


- TODO tests (config works + secrets exists + secrets are properly encrypted + no clash between users)
- logging



- users: some usersID are set by their own service. Now we FORCE it to a new value (our) but not sure if this is a good approach TODO


- Factorize the basic types (with constructors, e.g mkFStypeOption, mkDirOption, ...)
- Sanitize the code:
	+ avoid configs = in order to avoid infinite recursions 
	+ do everything in one step instead of having multiple evalModules
	+ move and regroup the code in order to never have a function editing multiple root fields of config (eg config.users and config.services)


- TODO add multiple provisioenrs in step-ca


- TODO: put a infra.vms."name".config containing the entire config of each vm ? THis could allow us to avoid infinite recursion
- TODO: params the ip address of the containers private network (actually its forced to be 192.168.100.0/24)

Deployement:
- curent refactor involved deployement options (like priority), but VMs may also have tags (like testing, backup) that is applied to their services
- priority should be a number. Max priority is the primary service.
- domains names are generated according to the priority. Eg the primary service is "postgres.local" and the first fallback "postgres-01.local". Testing services should be in a dedicated zone testing.local (eg postgres.testing.local, postgres-01.testing.local)

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


### Prio

- container mounts: pass directly the secret dir
- proxy conf
- Use UserID instead of proper user creation (for the secrets and files within the containers)
- All endpoints should be reachable by all HAproxies
- containerMount non-shared persistent volumes
- pg_ready services + fix pg-setup-script 
- haproxy: handle both tls termination + passthrough (https://pastebin.com/pkRsp9cc)
- config: use deploy.<name>.reverseProxy and deploy.<name>.proxy to handle clearly both directions of the proxy and resolves conflicts ?


CHECKS:
- check that each disk is declared once
- each disk is mounted on ONE mountpoint
- each mountpoint is declared by one disk
- Two services does not request the same repository

