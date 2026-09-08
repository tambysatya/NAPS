{flakeRoot, lib, inputs, config, pkgs, path,...}:



let
    utils = import "${flakeRoot}/lib" {inherit inputs lib;};
    servicevhost = "auth.${infra.domain}";
    serviceaddr = "127.0.0.1";
    serviceport = 8000;
in {
    config = lib.mkIf (infralib.runsService "keycloak")
        {

                services.keycloak = {
                  enable = true;
                  initialAdminPassword = builtins.readFile "${path}/.secrets/git/keycloak-initial-admin";

                  database = {
                    passwordFile = "/var/lib/secrets/db-keycloak.key";
                    useSSL = true;
                    host = "postgres.${infra.domain}";
                    caCert = "/etc/intermediate_ca.crt";
                  };
                  settings = {
                    hostname = servicevhost;
                    http-host = serviceaddr;
                    http-port = serviceport;
                    proxy-headers = "xforwarded";
                    http-enabled = true;
                    truststore-paths = "/etc/root_ca.crt";
                    
                  };
                };
           };
}
