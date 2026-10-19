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
    users.postgres = {service = "postgresql"; uid=10005;};
    assets = {
        ${hostname} = {
            provider = "tls";
            generateArgs = {inherit hostname;};
            installArgs = {inherit owner;};
            inherit reload;
        };
    };
    persistent = [
        {path = "/var/lib/postgresql"; inherit owner reload;}
    ];
};

}

