{inputs, config, lib, pkgs,...}:
let
 
    topology= config.naps.topology;
    hostname = "git.${topology.domain}";
    reload = ["forgejo.service" "forgejo-dump.service" "forgejo-init-password.service"];
    owner = "forgejo";

in
{
naps.services.forgejo = {
    path = ./.;
    users.forgejo = {service="forgejo"; uid=10010;};
    assets = {
        "forgejo-admin.key" = {
            provider = "password";
            args = {opensslType = "base64"; opensslSize=64; inherit owner;};
            inherit owner;
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
        http = [{
           inherit hostname; port = 3000; tls = true; 
        }];
        tcp = [{
           inherit hostname; port = 5022; #SSH connection
        }];
    };
    persistent = [
        {path = "/var/lib/forgejo"; shared=false; inherit owner reload;}
    ];
};
}
