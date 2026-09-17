{inputs, config, lib, pkgs,...}:

let

    topology = config.naps.topology;
    hostname = "postgres.${topology.domain}";
    owner = "postgres";
    reload = ["postgresql.service"];
in {

naps.services.postgres = {
    users.postgres = {service = "postgresql"; uid=10005;};
    store.sslCertificates = [
        {inherit hostname owner reload;}
    ];
    endpoints.tcp = [
        {inherit hostname; port = 5432;}
    ];
    persistent = [
        {path = "/var/lib/postgresql"; inherit owner reload;}
    ];
};

}

