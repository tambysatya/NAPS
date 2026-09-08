{flakeRoot, lib, inputs, config, pkgs, infra,...}:

let 

    utils = import "${flakeRoot}/lib" {inherit inputs lib;};
    domain = infra.topology.domain;
    dbaccesses = lib.concatMap ({links,...}: links.postgres) (builtins.attrValues config.infra.services); #list of dbAccesses in the infrastructure
    users = lib.map (access: 
                        {
                            name = access.database;
                            ensureDBOwnership = true; # creates a database of the same name #TODO
                            ensureClauses = { login = true; };
                        }) dbaccesses;

in {

config = 
        {  
            networking.firewall.allowedTCPPorts = [5432];
            services.postgresql = {
                enable = true;
                enableTCPIP = true;

                authentication = ''
                    local all all peer
                    hostssl all all all scram-sha-256
                    '';
                ensureUsers = users; 
                ensureDatabases = map (builtins.getAttr "database") dbaccesses; 

                settings = {
                    password_encryption = "scram-sha-256";
                    ssl = true;
                    ssl_cert_file = vars.ssl_crt_path "postgres.${domain}";
                    ssl_key_file = vars.ssl_key_path "postgres.${domain}";
                    ssl_ca_file = "/etc/root_ca.crt";
                };
            };
            systemd.services.postgresql-password = {
                description = "Configure PostgreSQL passwords and permissions";

                after = [ "postgresql-setup.service"];
                requires = [ "postgresql-setup.service" ];
                wantedBy = ["multi-user.target"];

                serviceConfig = {
                    Type = "oneshot";
                    User = "postgres";

                };

                script = lib.concatStringsSep "\n"
                                    (access@{database,...}:
                                        ''
                                              PASSWORD="$(< /run/secrets/db-${name}-${access.database}.key)"
                                              ${pkgs.postgresql}/bin/psql -U postgres \
                                                -c "ALTER ROLE ${access.database} WITH PASSWORD '$PASSWORD';"
                                        '')
                                    dbacceses;


            };
        };

}
