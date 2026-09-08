{flakeRoot, lib, inputs, config, pkgs, infra,...}:

let 

    utils = import "${flakeRoot}/lib" {inherit inputs lib;};
    domain = infra.topology.domain;
    dbaccesses = lib.concatMap ({links,...}: links.postgres) (builtins.attrValues infra.services); #list of dbAccesses in the infrastructure
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
                    ssl_cert_file = "/var/lib/secrets/postgres.${domain}.crt";
                    ssl_key_file = "/var/lib/secrets/postgres.${domain}.key";
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

                script = lib.concatMapStringsSep "\n"
                                    (access@{database,...}:
                                        ''
                                              PASSWORD="$(< /run/secrets/db-${access.database}.key)"
                                              ${pkgs.postgresql}/bin/psql -U postgres \
                                                -c "ALTER ROLE ${access.database} WITH PASSWORD '$PASSWORD';"
                                        '')
                                    dbaccesses;


            };
        };

}
