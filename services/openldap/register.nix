{lib, inputs,  pkgs, config, ...}:

let 

    topology = config.naps.topology;
    hostname = "openldap.${topology.domain}";
    owner = "openldap";
    reload = ["openldap.service"];
in {

naps.services.openldap = {
    provides = ["ldap"];
    path = ./.;
    users.openldap = {service="openldap"; uid=10004;};
    assets."tls" = {
        ${hostname} = {
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

    configureListen = addr: {
        config.services.openldap.urlList = ["ldap://${addr}" "ldaps://${addr}" "ldapi://"];
    };
};

}

