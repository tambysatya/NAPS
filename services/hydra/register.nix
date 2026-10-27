{flakeRoot, lib, inputs, config,...}:

let

    domain = config.naps.topology.domain;
    owner = "hydra";
    reload = ["hydra-server.service" "hydra-init.service"];
    endpoints = {
        https = [
            {
                hostname = "hydra.${domain}";
                port = 3000;
                extraArgs = {tls = "termination";};
            }
            {
                hostname = "cache.${domain}";
                port = 3001;
                extraArgs = {tls = "termination";};
            }
        ];
    };
    links  = {
        postgres = [
            {database = "hydra"; inherit owner reload;}
        ];
    };

in { 

naps.services.hydra ={
    path = ./.;
    users."hydra" = {service ="hydra"; uid=10007;};
    inherit links endpoints;
    configureListen = addr: {
        config.services = {
            hydra.listenHost = addr;
            darkhttpd.address = addr;
        };
    };
    assets = {
        "password" = {
            "hydra-admin-pass.key" = {
                generateArgs = {opensslType = "base64"; opensslSize = 64;};
                installArgs = {owner = "hydra";};
                inherit reload;
            };
        };
        "ssh-keygen" = {
            "hydra-ssh" = {
                generateArgs = {keyname = "hydra";};
                installArgs = {owner = "hydra"; path = "/var/lib/hydra/.ssh";};
                inherit reload;
            };
        };
        "nix-store" = {
            "hydra-cache" = {
                generateArgs = {keyname = "hydra";};
                installArgs = {owner = "hydra"; mode="0440";};
                inherit reload;
            };
        };
    };
    persistent = [
        {path = "/nix"; owner="root"; reload=[]; mode="755";}
        {path = "/var/lib/hydra/cache"; owner="hydra-queue-runner:hydra"; reload=reload; mode="755";}
    ];
};
}
