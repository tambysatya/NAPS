{flakeRoot, inputs, config, lib, pkgs,...}:
let
    topology= config.naps.topology;
    hostname = "git.${topology.domain}";
    reload = [
        "forgejo.service" 
        #"forgejo-dump.service"  # useful TODO ?
        "forgejo-init-password.service"
    ];
    owner = "forgejo";

in
{
naps.services.forgejo = {
    path = ./.;
    users.forgejo = {service="forgejo"; uid=10010;};
    assets."password" = {
        "forgejo-admin.key" = {
            generateArgs = {opensslType = "base64"; opensslSize=64;};
            installArgs = {inherit owner;};
            inherit reload;
        };
    };
    links = {
        postgres = [
            {database = "forgejo"; inherit owner reload;}
        ];
        s3 = [
            {bucket = "forgejo"; inherit owner reload;}
        ];
    };
    endpoints = {
        https = [{
           inherit hostname; port = 3000; extraArgs = {tls = "termination";};
        }];
        tcp = [{
           inherit hostname; port = 5022; #SSH connection
        }];
    };
    configureListen = addr: {services.forgejo.settings.server.HTTP_ADDR = addr;};
    persistent = {
        "/var/lib/forgejo" = { shareable=true; inherit owner reload; group = null;};
    };


};
}
