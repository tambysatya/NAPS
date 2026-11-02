{flakeRoot, lib, inputs, pkgs, config, path, ...}:

let

    utils = import "${flakeRoot}/lib" {inherit inputs lib flakeRoot;};

    proxyAndFirewallConfigs = 
        let
            outputs = config.naps.internal.endpoints.outputs;
            processProxy = envuid: str: {config.services.haproxy.config = str;};
            processFirewall = 
                envuid: fwconfig: {
                    config.networking.firewall.interfaces = 
                        lib.mapAttrs 
                            (iface: protoconfig: 
                                lib.mapAttrs 
                                    (proto: ports: 
                                        if proto == "tcp" then {allowedTCPPorts = ports;}
                                        else if proto == "udp" then {allowedUDPPorts = ports;}
                                        else throw "firewall: unknown protocol ${proto}")
                                    protoconfig) 
                            fwconfig;
                    };
            generateEtcHosts = 
                envuid: {reaches, ...}:
                let
                    env = config.naps.internal.envs.all.${envuid};
                    proxyIP = utils.envPrivateHostIP env;
                    processEPProvider = provider: endpoints: lib.mapAttrsToList (_: {hostname,...}: hostname) endpoints;
                in {
                    config.networking.hosts.${proxyIP} = lib.unique (utils.concatMapAttrsToList processEPProvider reaches);
                };
            /* Allows haproxy to bind on non-existing interfaces if at least one container
               requires a forward proxy */
            allowNonLocalBind = 
                envuid: {reaches, ... }: 
                    let env = config.naps.internal.envs.all.${envuid};
                    in lib.optionalAttrs (utils.isContainer env && reaches != {}) {
                        ${utils.envHostUID env}.config.boot.kernel.sysctl = {
                                "net.ipv4.ip_nonlocal_bind" = 1;
                                "net.ipv6.ip_nonlocal_bind" = 1;
                        };
                };
        in lib.mkMerge [
                (lib.mapAttrs processProxy outputs.proxy)
                (lib.mapAttrs processFirewall outputs.firewall)
                (lib.mapAttrs generateEtcHosts config.naps.internal.endpoints.perEnv)
                (lib.mkMerge (lib.mapAttrsToList allowNonLocalBind config.naps.internal.endpoints.perEnv))
           ];

    processServices = # enable and configures the services on the deployement environment
        srvname: srvconf@{configureListen, instances, path, ...}:
        let
            processInstance = insname: ins: {
                ${utils.insEnvUID ins} = {
                    # native endpoints listens on 127.0.0.2 because 127.0.0.1 belongs to the forward proxy
                    config = configureListen (if utils.runsInContainer ins then "0.0.0.0" else "127.0.0.2"); 
                    imports = [path];
                };
            };
        in lib.mkMerge (lib.mapAttrsToList processInstance instances);


in

{
    imports = [
               #./volumes.nix
               #./network.nix
               ./users.nix
              ];
    naps.outputs.systems = lib.mkMerge [
        config.naps.internal.envs.outputs # basic netwroking for vms and containers (ip addresses, gateway,...)
        config.naps.internal.assets.outputs.config # assets services (e.g. step-renew for TLS refresh): defined in internal.assets
        config.naps.internal.links.outputs # dependencies across the infrastructure (e.g. wait-uplinks services): defined in internal.links
        proxyAndFirewallConfigs # haproxy + firewall configuration of VMs: defined in internal.endpoints
        (lib.mkMerge (lib.mapAttrsToList processServices config.naps.internal.services)) # services imports + config (listen...)
    ];
    #naps.outputs = utils.mergeAll (lib.mapAttrsToList processSystem config.naps.deploy.systems);
    /*
    naps.outputs.systems = 
        utils.mergeAll [
            (lib.mapAttrs processUsers config.naps.deploy.systems)
            (lib.mapAttrs mkRoot config.naps.deploy.systems)
            (utils.mergeAll (lib.mapAttrsToList addServices config.naps.internal.services))
        ];
    */
}
