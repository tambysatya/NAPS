{lib, inputs, config, pkgs, ...}:

let 
    topology = config.naps.topology;
    domain = topology.domain;

    owner = "garage";
    reload = ["garage.service"];
    filemode = "0400";
    opensslSize = 32;
    opensslType = "hex";

in {

config.naps.services.garage = {
    path = ./.;
    users."garage" = {service = "garage"; uid=10001;};
    assets = {
        "garage-rpc.key" = {
            provider = "password";
            generateArgs = {inherit opensslSize opensslType;};
            installArgs = {inherit owner;};
            inherit reload;
        };
        "garage-admin.key" = {
            provider = "password";
            generateArgs = {inherit opensslSize opensslType;};
            installArgs = {inherit owner;};
            inherit reload;
        };
        "garage-metrics.key" = {
            provider = "password";
            generateArgs = {inherit opensslSize opensslType;};
            installArgs = {inherit owner;};
            inherit reload;
        };
    };
    persistent = [
        {path="/srv/data"; inherit owner reload; mode = "0700";}
        {path="/srv/meta"; inherit owner reload; mode = "0700";}
    ];
    endpoints.http= [
        {hostname="s3.${domain}"; port=3900; tls = true;}
        {hostname="s3-admin.${domain}";port=3903; tls = true;}
    ];
};
}


