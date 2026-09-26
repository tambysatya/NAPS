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
    assets= {
            "keycloak-initial-admin.key" = {
                provider = "password";
                generateArgs = {opensslSize = 64; opensslType = "base64";};
                installArgs = {inherit owner;};
            };
    };
    links = {
        postgres = [
            {database="keycloak"; inherit owner;}
        ];  
    };
    endpoints.http = [
        {inherit hostname port; tls=true;}
    ];
};

}

