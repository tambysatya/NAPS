/* Automatizes the creation of services to ensure dependency between services across the network */

{inputs, lib, pkgs, naps, ...}:
let
     mkDBDependencies = reloads: 
                    lib.mkIf (reloads != []) {
                        systemd.services."postgres-wait" = {
                            description = "Waiting for postgres to be reachable [dependency of service]...";
                            wants = [
                                "network.target"
                            ];
                            after = [
                                "network.target"
                            ];
                            before = reloads;
                            requiredBy = reloads;
                            serviceConfig = { 
                                Type = "oneshot";

                                    #"${pkgs.netcat}/bin/nc -z postgres.${naps.domain} 5432"; # wait for the database to be up²
                                ExecStart = pkgs.writeShellScript "wait-for-postgres" '' 
                                        until ${pkgs.postgresql}/bin/pg_isready -h postgres.${naps.domain} -p 5432; do
                                            sleep 1
                                        done
                                    '';
                                #Restart = "on-failure";
                                #RestartSec = "30s"; 
                            };
                        };
                    };

in {
    inherit mkDBDependencies;
}
