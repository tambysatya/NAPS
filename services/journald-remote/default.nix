{lib, inputs, config, topology, ...}:

let domain = "journald.${topology.domain}";
    

in {
    services.journald.remote  = {
        enable = true;
        settings = {
            Remote = {
                ServerCertificateFile = "/var/lib/secrets/${domain}.crt";
                ServerKeyFile = "/var/lib/secrets/${domain}.key";
                TrustedCertificateFile = "/etc/intermediate_ca.key";
            };
            
        };
    };
}
