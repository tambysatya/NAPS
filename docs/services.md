# Adding a new service

So far, the number of services available to be deployed with NAPS is quite limited (actually restricted to the services my colleagues and I are using in our respective lab). However, NAPS is designed as extensible framework allowing people to easily declare new services in order to automatize their deployement. 

In addition to the usual nixos-configuration of the service, NAPS provides an interface in order to specify what is needed by a service. As an example, consider the following declaration of the nextcloud service which we will dismantle step by step in this chapter.

```nix

let
    topology= config.naps.topology;
    hostname = "nextcloud.${topology.domain}";
    owner = "nextcloud";
    reload = ["phpfpm-nextcloud.service" "nextcloud-setup.service"];
in {

naps.services.nextcloud = {

    # path to the nixos-configuration of the service
    path = ./default.nix; 

    users.nextcloud = {service="nextcloud"; uid=10003;};
    assets."password" = {
            "nextcloud-admin.key" = {
                generateArgs = {opensslType = "base64"; opensslSize=64;};
                installArgs = {inherit owner;};
                reload = ["phpfpm-nextcloud.service"];
            };
    };
    links = {
        postgres = [
            {database = "nextcloud"; inherit owner reload;}
        ];
        s3 = [
            {bucket = "nextcloud"; inherit owner reload;}
        ];
    };
    persistent = {
        "/var/lib/nextcloud/config" = {shareable=true; inherit owner reload;};
        "/var/lib/nextcloud/data" = {shareable=true; inherit owner reload;};
    };
    endpoints.https = [{
                   hostname = hostname;
                   port = 80; 
                   extraArgs = {tls = "termination";};
                 }];

    configureListen = addr: {
        services.nginx.virtualHosts.${hostname}.listen = [ {inherit addr; port=80;}];
    };

};

```

- `naps.services.<name>.path`:

Specifies the location of the nix configuration file of the service, which will serve as a *default* configuration file. 

```nix
path = ./default.nix; 
```


```nix

```
```nix

```
```nix

```

```nix

```
```nix

```
```nix

```
