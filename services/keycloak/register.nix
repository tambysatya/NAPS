{lib, inputs, pkgs, config, ...}:

let 
    hostname = "auth.${config.naps.topology.domain}";
    port = 8000;

    owner="root";
    reload = ["keycloak.service"];

in 
{

naps.services.keycloak = {
    path = ./.;
    users.keycloak = {service ="keycloak"; uid=10002;};
    store = {
        plain = [
            {filename="keycloak-initial-admin.key"; opensslSize = 64; opensslType = "base64";}
        ];
    };
    links = {
        postgres = [
            {database="keycloak"; inherit owner reload;}
        ];  
    };
    endpoints.http = [
        {inherit hostname port; tls=true;}
    ];
};

}

