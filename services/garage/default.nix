{flakeRoot, lib, inputs, pkgs, config,...}:

let 
    utils = import "${flakeRoot}/lib" {inherit lib inputs;};

    s3lib = import ./lib.nix {inherit lib inputs pkgs flakeRoot;};
    accesses = lib.concatMap (_: {links,...}: links.s3) config.infra.services;
    


in {
config = lib.mkIf 
            (infralib.runsService "garage")
            (lib.mkMerge [
                    (sec.generateSecret secret)
                    { 
                        services.garage = 
                        {
                            enable = true;
                            package = pkgs.garage_2; 
                            settings = 
                            {
                                #data_dir = "/srv/data";
                                #metadata_dir = "/srv/meta";
                                rpc_bind_addr = "[::]:3901";
                                rpc_secret_file = "/var/lib/secrets/garage-rpc.key";
                                replication_factor = 1;

                                /* TESTS */
                               # metadata_fsync = false;
                               # data_fsync=false;
                               # compression_level="none";
                               # block_size = "32M";
                               # #############################

                                s3_api = 
                                {
                                    api_bind_addr = "127.0.0.1:3900"; # localhost because not encrypted
                                        s3_region = "garage";
                                    root_domain = "s3.${infra.domain}";
                                };
                                admin = {
                                    api_bind_addr = "127.0.0.1:3903"; # localhost because not encrypted
                                    admin_token_file = "/var/lib/secrets/garage-admin.key";
                                    metrics_token_file =  "/var/lib/secrets/garage-metrics.key";
                                };
                            };
                        };


                        users.users.garage = {
                            isSystemUser = true;
                            group = "garage";
                            home = "/var/lib/garage";
                            createHome = true;
                        };
                        users.groups.garage = {};
                        systemd.services.garage = {
                            serviceConfig = {
                                DynamicUser = false;
                                User = "garage";
                                Group = "garage";
                                StateDirectory = "garage";

                            };
                            after = ["garage-permissions.service"];
                            requires = ["garage-permissions.service"];
                        };

                        systemd.services.garage-permissions = {
                            description = "Garage volumes permissions";
                            wantedBy = ["multi-agent.target"];

                            after = [
                                "srv-meta.mount"
                                "srv-data.mount"
                            ];
                            requires = [
                                "srv-meta.mount"
                                "srv-data.mount"
                            ];

                            serviceConfig.Type = "oneshot";
                            script = ''
                                chown -R garage:garage /srv/meta
                                chown -R garage:garage /srv/data
                            '';
                        };

                        systemd.services.garage-bootstrap = {
                            description = "Bootstrap the configuration of garage (bucket creation and keys assignments)";
                            after = ["garage.service"];
                            requires = ["garage.service"];
                            wantedBy = ["multi-user.target"];
                            serviceConfig = {
                                Type = "oneshot";
                                StateDirectory = "garage";
                                Restart = "on-failure";
                                RestartSec = "30s";
                            };
                            script = lib.concatStringsSep "\n" 
                                            [s3lib.bootstrapNode
                                             (lib.concatMapStringsSep "\n" 
                                                s3lib.generateAccess accesses)];
                        };
                    }
        ]);
}
