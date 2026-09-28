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
            provider = "tls";
            generateArgs = {inherit hostname;};
            installArgs = {inherit owner;};
            inherit reload;
        };
    };
    links = {
        ldap = [
            {olcRootDN ="cn=admin"; inherit owner reload;} #TODO add the suffix
        ];
    };

    persistent = [
        {path="/var/lib/openldap/data"; inherit owner reload;}
    ];
};

}

