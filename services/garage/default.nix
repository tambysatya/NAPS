{flakeRoot, lib, inputs, pkgs, config, topology, services, ...}:

let 
    utils = import "${flakeRoot}/lib" {inherit lib inputs;};

    s3lib = import ./lib.nix {inherit lib inputs pkgs flakeRoot;};
    accesses = lib.concatMap ({links,...}: links.s3) (builtins.attrValues services);
    


in {
config = 
    { 
        services.garage = 
        {
            enable = true;
            package = pkgs.garage_2; 
            settings = 
            {
                rpc_bind_addr = "[::]:3901";
                rpc_secret_file = "/var/lib/secrets/garage-rpc.key";
                replication_factor = 1;
                s3_api = {
                    api_bind_addr = "127.0.0.1:3900"; # localhost because not encrypted
                    s3_region = "garage";
                    root_domain = "s3.${topology.domain}";
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
                "var-lib-garage-meta.mount"
                "var-lib-garage-data.mount"
            ];
            requires = [
                "var-lib-garage-meta.mount"
                "var-lib-garage-data.mount"
            ];

            before = ["garage.service"];
            requiredBy = ["garage.service"];

            serviceConfig.Type = "oneshot";
            script = ''
                chown -R garage:garage /var/lib/garage/meta
                chown -R garage:garage /var/lib/garage/data
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
    };
}
