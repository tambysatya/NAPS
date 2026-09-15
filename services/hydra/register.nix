{flakeRoot, lib, inputs, config,...}:

let

    domain = config.infra.topology.domain;
    owner = "hydra";
    reload = ["hydra.service" "hydra-init.service"];
    endpoints = {
        http = [
            {
                hostname = "hydra.${domain}";
                port = 3000;
                tls = true;
            }
        ];
    };
    links  = {
        postgres = [
            {database = "hydra"; inherit owner reload;}
        ];
    };

in { 

infra.services.hydra ={
    users."hydra" = {service ="hydra"; uid=10007;};
    inherit links endpoints;
    store.passwords = [
        {filename = "hydra-admin-pass.key"; owner="hydra"; opensslType = "base64"; opensslSize=64;}
    ];
    persistent = [
        {path = "/nix"; owner="root"; reload=[]; mode="755";}
        {path = "/var/lib/hydra/cache"; owner="hydra"; reload=reload; mode="755";}
    ];
};
}
