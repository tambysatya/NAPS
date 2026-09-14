{lib, inputs, config, topology, ...}:

let domain = "journald.${topology.domain}";
    

in {
    #networking.firewall.allowedTCPPorts = [19532];
    services.journald.remote  = {
        enable = true;
        listen = "http";
        settings = {
            Remote = {
                ServerCertificateFile = "/var/lib/secrets/${domain}.crt";
                ServerKeyFile = "/var/lib/secrets/${domain}.key";
            };
        };
    };
}
