{flakeRoot, lib, inputs, config,...}:

let

    domain = config.infra.topology.domain;
    owner = "hydra";
    reload = ["hydra.service"];
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
    users = [{name=owner; uid=10007;}];
    inherit links endpoints;
    store.passwords = [
        {filename = "hydra-admin-pass.key"; owner="hydra"; opensslType = "base64"; opensslSize=64;}
    ];
};
}
