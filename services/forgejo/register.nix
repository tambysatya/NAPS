{inputs, config, lib, pkgs,...}:
let
 
    topology= config.infra.topology;
    hostname = "git.${topology.domain}";
    reload = ["forgejo.service" "forgejo-dump.service"];
    owner = "forgejo";

in
{
infra.services.forgejo = {
    users.forgejo = {service="forgejo"; uid=10010;};
    store.passwords = [
        {filename = "forgejo-admin.key"; opensslType = "base64"; opensslSize=64; inherit owner;}
    ];
    links = {
        postgres = [
            {database = "forgejo"; inherit owner reload;}
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
