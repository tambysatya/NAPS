{flakeRoot, lib, inputs, config,...}:

let

    domain = config.naps.topology.domain;
    owner = "hydra";
    reload = ["hydra.service" "hydra-init.service"];
    endpoints = {
        http = [
            {
                hostname = "hydra.${domain}";
                port = 3000;
                tls = true;
            }
            {
                hostname = "cache.${domain}";
                port = 8080;
                tls = true;
            }
        ];
    };
    links  = {
        postgres = [
            {database = "hydra"; inherit owner reload; pgpass=true;}
        ];
    };

in { 

naps.services.hydra ={
    path = ./.;
    users."hydra" = {service ="hydra"; uid=10007;};
    inherit links endpoints;
    assets = {
        "hydra-admin-pass.key" = {
            provider = "password";
            generateArgs = {opensslType = "base64"; opensslSize = 64;};
            installArgs = {owner = "hydra";};
            inherit reload;
        };
        "hydra-ssh" = {
            provider = "ssh-keygen";
            generateArgs = {keyname = "hydra";};
            installArgs = {owner = "hydra"; path = "/var/lib/hydra/.ssh";};
            inherit reload;
        };
        "hydra-cache" = {
            provider = "nix-store";
            generateArgs = {keyname = "hydra";};
            installArgs = {owner = "hydra";};
            inherit reload;
        };
    };
    persistent = [
        {path = "/nix"; owner="root"; reload=[]; mode="755";}
        {path = "/var/lib/hydra/cache"; owner="hydra-queue-runner:hydra"; reload=reload; mode="755";}
    ];
};
}
