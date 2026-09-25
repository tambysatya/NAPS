{lib, inputs,  pkgs, config, ...}:

let 

    topology = config.naps.topology;
    hostname = "openldap.${topology.domain}";
    owner = "openldap";
    reload = ["openldap.service"];
in {

naps.services.openldap = {
    path = ./.;
    users.openldap = {service="openldap"; uid=10004;};
    endpoints.tcp = [
        {inherit hostname; port=389;}
        {inherit hostname; port=636;}
    ];
    assets = {
        ${hostname} = {
            provider = "sslCertificate";
            args = {inherit hostname reload;};
            inherit owner;
        };
    };
    links = {
        ldap = [
            {filename="ldap-admin.key"; opensslSize=64; opensslType="base64";}
        ];
    };

    persistent = [
        {path="/var/lib/openldap/data"; inherit owner reload;}
    ];
};

}

