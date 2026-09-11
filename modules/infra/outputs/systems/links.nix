{flakeRoot, lib, inputs, config, pkgs,...}:
let
    utils = import ../lib {inherit lib inputs flakeRoot;};
    domain = config.infra.topology.domain;
    mkDBDependencies = env: reloads:
        {
            ${utils.envUID env}.config.systemd.services."postgres-wait" = {
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
                    RemainAfterExit = true;
                    ExecStart = pkgs.writeShellScript "wait-for-postgres" '' 
                            until ${pkgs.postgresql}/bin/pg_isready -h postgres.${domain} -p 5432; do
                                sleep 1
                            done
                            echo "Connected to postgres"
                        '';
                };
            };
        };
    mkS3Dependencies = env: reloads:
        {
            ${utils.envUID env}.config.systemd.services."s3-wait" = {
                description = "Waiting for s3 to be reachable [dependency of service]...";
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
                    RemainAfterExit = true;
                    ExecStart = pkgs.writeShellScript "wait-for-s3" '' 
                            until ${pkgs.netcat}/bin/nc -z s3.${domain} 443; do
                                echo "Testing s3 connectivity..."
                                sleep 1
                            done
                            echo "Connected to s3."
                        '';
                };
            };
        };

    processSystem =
        sysname: links:
        let getServiceFromLink = 
                {access, env}: access.reload;
            sysenv = config.infra.deploy.systems.${sysname}.env;
        in utils.mergeAll [
            (mkDBDependencies sysenv (lib.concatMap getServiceFromLink links.postgres))
            (mkS3Dependencies sysenv (lib.concatMap getServiceFromLink links.s3))
        ];

in {
    infra.outputs.systems = utils.mergeAll (lib.mapAttrsToList processSystem config.infra.links);
}
