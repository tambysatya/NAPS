{flakeRoot, lib, inputs, config,...}:
let
    domain = config.infra.topology.domain;
    hostname = "journald.${domain}";
    owner = "systemd-journal-remote";
    reload = ["systemd-journal-remote.service"];
    endpoints = {
        tcp = [ #journald use mTLS internally
            {
                inherit hostname;
                port = 19532;
            }
        ];
    };
    ssl = {inherit hostname owner reload;};
in {
infra.services.journald-remote = {
    users = {
        "systemd-journal-remote" = {service ="systemd-journal-remote"; uid=10008;};
        "systemd-journal-upload" = {service ="systemd-journal-upload"; uid=10009;}; #clients
    };
    store.sslCertificates = [ssl];
    inherit endpoints;
};
}



