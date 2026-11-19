{flakeRoot, lib, inputs, pkgs, config, path, ...}:

let

    utils = import "${flakeRoot}/lib" {inherit inputs lib flakeRoot;};

    proxyAndFirewallConfigs = 
        let
            outputs = config.naps.endpoints.outputs;
            processProxy = envuid: str: {
                config.services.haproxy.config = ''
                        ssl-server-verify none
                    defaults
                        timeout connect 5s

                        # connections are handled by the kernels
                        timeout client 0
                        timeout server 0
                        option tcpka

                    ${str}
                '';
            };
            processFirewall = 
                envuid: fwconfig: {
                    config.networking.firewall.interfaces = 
                        lib.mapAttrs 
                            (iface: protoconfig: 
                                lib.mkMerge (
                                    lib.mapAttrsToList 
                                        (proto: ports: 
                                            if proto == "tcp" then {allowedTCPPorts = ports;}
                                            else if proto == "udp" then {allowedUDPPorts = ports;}
                                            else throw "firewall: unknown protocol ${proto}")
                                        protoconfig))
                            fwconfig;
                    };
            generateEtcHosts = 
                envuid: _:
                {
                    config.networking.hosts = config.naps.endpoints.outputs.hostsFile.${envuid};
                };
            /* Allows haproxy to bind on non-existing interfaces if at least one container
               requires a forward proxy */
            allowNonLocalBind = 
                vmname: alleps: 
                    let vmenv = config.naps.envs.all.${vmname};
                        ctRequiresForward =  
                            builtins.any 
                                (reaches: lib.mapAttrsToList (envuid: {env, ...}: utils.isContainer env) reaches != {})
                                (lib.mapAttrsToList (proto: {reaches, exposes}: reaches) alleps);
                    in lib.optionalAttrs ctRequiresForward {
                        ${vmname}.config.boot.kernel.sysctl = {
                                "net.ipv4.ip_nonlocal_bind" = 1;
                                "net.ipv6.ip_nonlocal_bind" = 1;
                        };
                };
        in lib.mkMerge [
                (lib.mapAttrs processProxy outputs.proxy)
                (lib.mapAttrs processFirewall outputs.firewall)
                (lib.mapAttrs generateEtcHosts config.naps.endpoints.perEnv)
                (lib.mkMerge (lib.mapAttrsToList allowNonLocalBind config.naps.endpoints.perVM))
                (lib.mapAttrs (name: _: {config.services.haproxy.enable = true;}) config.naps.envs.vms)
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
               ./users.nix
               ./commons.nix
              ];
    naps.outputs.systems = lib.mkMerge [
        config.naps.envs.outputs # basic networking for vms and containers (ip addresses, gateway,...)
        config.naps.persistent.outputs # persistency + root filesystems
        config.naps.assets.outputs.config # assets services (e.g. step-renew for TLS refresh): defined in assets
        config.naps.links.outputs # dependencies across the infrastructure (e.g. wait-uplinks services): defined in links
        proxyAndFirewallConfigs # haproxy + firewall configuration of VMs: defined in endpoints
        (lib.mkMerge (lib.mapAttrsToList processServices config.naps.services)) # services imports + config (listen...)
    ];
}
