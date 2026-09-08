{flakeRoot, lib, inputs, config, pkgs,...}:
let
    utils = import ../lib {inherit lib inputs flakeRoot;};
    domain = config.infra.topology.domain;
    mkDBDependencies = reloads:
        {
            config.systemd.services."postgres-wait" = {
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
    mkS3Dependencies = reloads:
        {
            config.systemd.services."s3-wait" = {
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

    processVM =
        vmname: links:
        let getServiceFromLink = 
                {access, env}:
                if env.type == "container"
                then ["container@${utils.envUID env}.service"] # in case of service running within a container, the dependency is the container itself
                else access.reload;
        in utils.mergeAll [
            (mkDBDependencies (lib.concatMap getServiceFromLink links.postgres))
            (mkS3Dependencies (lib.concatMap getServiceFromLink links.s3))
        ];

in {
    infra.outputs.systems = lib.mapAttrs processVM config.infra.links.perVM;
}
