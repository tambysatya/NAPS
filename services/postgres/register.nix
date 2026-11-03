{inputs, config, lib, pkgs,...}:

let

    topology = config.naps.topology;
    hostname = "postgres.${topology.domain}";
    owner = "postgres";
    reload = ["postgresql.service"];
in {

naps.services.postgres = {
    path = ./.;
    provides = ["postgres"];
    configureListen = addr: {
        services.postgresql.settings.listen_addresses = lib.mkForce addr;
    };
    users.postgres = {service = "postgresql"; uid=10005;};
    assets."tls" = {
        ${hostname} = {
            generateArgs = {inherit hostname;};
            installArgs = {inherit owner;};
            inherit reload;
        };
    };
    persistent = {
        "/var/lib/postgresql" = {inherit owner reload;};
    };
};

}

