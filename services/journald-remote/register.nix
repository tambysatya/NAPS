{flakeRoot, lib, inputs, config,...}:
let
    domain = config.naps.topology.domain;
    hostname = "journald.${domain}";
    owner = "systemd-journal-remote";
    reload = ["systemd-journal-remote.service"];
    endpoints = {
        http= [ #journald use mTLS internally
            {
                inherit hostname;
                port = 19532;
                extraConfig = {
                    frontend  = {
                        bind = "verify required ca-file /etc/root_ca.crt";
                    };
                };
                tls = true;
            }
        ];
    };
    #ssl = {inherit hostname owner reload;};
in {
naps.services.journald-remote = {
    path = ./.;
    users = {
        "systemd-journal-remote" = {service ="systemd-journal-remote"; uid=10008;};
        "systemd-journal-upload" = {service ="systemd-journal-upload"; uid=10009;}; #clients
    };
    persistent = [
        {path = "/var/log/journal/remote"; shared=false; inherit owner reload;}
    ];
    inherit endpoints;
};
}



