{inputs, config, lib, pkgs,...}:

let
 
    topology= config.naps.topology;
    hostname = "nextcloud.${topology.domain}";
    owner = "nextcloud";
    reload = ["phpfpm.service" "nextcloud-setup.service"];

    endpoints = [{
                   hostname = hostname;
                   port = 80; 
                   tls = true;
                 }];
in {

naps.services.nextcloud = {
    path = ./.;
    users.nextcloud = {service="nextcloud"; uid=10003;};
    assets = {
            "nextcloud-admin.key" = {
                provider = "password";
                args = {opensslType = "base64"; opensslSize=64;};
                inherit owner;
            };
    };
    links = {
        postgres = [
            {database = "nextcloud"; inherit owner;}
        ];
        s3 = [
            {bucket = "nextcloud"; inherit owner;}
        ];
    };
    persistent = [
        {path="/var/lib/nextcloud/config"; shared=true; inherit owner reload;}
        {path="/var/lib/nextcloud/data"; shared=true; inherit owner reload;}
    ];
    endpoints.http = endpoints;

};

}

