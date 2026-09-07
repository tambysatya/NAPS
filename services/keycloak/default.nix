{lib, inputs, infra, registry, vmname, vmconf, pkgs, config, ...}:



let
    
    vars = import "${inputs.self.outPath}/lib/vars.nix" {inherit inputs lib infra pkgs registry;};
    infralib = import "${inputs.self.outPath}/lib/infra" {inherit lib vmconf vmname;};
    servicevhost = "auth.${infra.domain}";
    serviceaddr = "127.0.0.1";
    serviceport = 8000;
in {
    config = lib.mkIf (infralib.runsService "keycloak")
        {

                services.keycloak = {
                  enable = true;
                  initialAdminPassword = builtins.readFile "${infra.flakePath}/${vars.git}/keycloak-initial-admin";

                  database = {
                    passwordFile = config.sops.secrets."db-keycloak-keycloak.key".path;
                    useSSL = true;
                    host = "postgres.${infra.domain}";
                    #caCert = "/etc/intermediate_ca.crt";
                    caCert = "/etc/ssl/certs/ca-bundle.crt";
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
