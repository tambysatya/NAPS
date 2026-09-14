{lib, inputs, config, topology, ...}:

let domain = "journald.${topology.domain}";
    

in {
    networking.firewall.allowedTCPPorts = [19532];
    services.journald.remote  = {
        enable = true;
        settings = {
            Remote = {
                ServerCertificateFile = "/var/lib/secrets/${domain}.crt";
                ServerKeyFile = "/var/lib/secrets/${domain}.key";
                TrustedCertificateFile = "/etc/root_ca.crt";
            };
        };
    };
    systemd.services.systemd-journal-remote.serviceConfig = {
        ReadOnlyPath = [
            "/etc/root_ca.crt"
        ];
    };
}
