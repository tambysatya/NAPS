{inputs, config, lib, pkgs,...}:

let
 
    topology= config.naps.topology;
    hostname = "nextcloud.${topology.domain}";
    owner = "nextcloud";
    reload = ["phpfpm.service" "nextcloud-setup.service"];
    /*
    extraConfig = {
        virtualHosts.${hostname}.extraConfig = 
            ''
                proxy_request_buffering off;
                proxy_buffering off;
                proxy_http_version 1.1;
                proxy_read_timeout 1h;
                proxy_send_timeout 1h;
                send_timeout 3600s;

                keepalive_timeout 65s;
                proxy_set_header Connection "";

                client_body_timeout 3600s;
                fastcgi_request_buffering off;
                fastcgi_read_timeout 3600s;


            '';
        clientMaxBodySize = "100G";
    };
    */



    endpoints = [{
                   hostname = hostname;
                   port = 80; 
                   tls = true;
                 }];
in {

naps.services.nextcloud = {
    users.nextcloud = {service="nextcloud"; uid=10003;};
    store = {
        passwords = [
            {filename = "nextcloud-admin.key"; opensslType = "base64"; opensslSize=64; inherit owner ;}
        ];
    };
    links = {
        postgres = [
            {database = "nextcloud"; inherit owner reload;}
        ];
        s3 = [
            {bucket = "nextcloud"; inherit owner reload;}
        ];
    };
    persistent = [
        {path="/var/lib/nextcloud/config"; shared=true; inherit owner reload;}
        {path="/var/lib/nextcloud/data"; shared=true; inherit owner reload;}
    ];
    endpoints.http = endpoints;

};

}

