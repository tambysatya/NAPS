{flakeRoot, lib, inputs, pkgs, config, path, ...}:

let

    utils = import "${flakeRoot}/lib" {inherit inputs lib flakeRoot;};

    /*
    mkUser = user: {service, uid}:
        {
            users.${user} = {
                uid = lib.mkForce uid;
                group = user;
                isSystemUser = true;
            };
            groups.${user} = {
                gid = lib.mkForce uid;
            };
        };
    processUsers =  # Adds the users declared by the VM + systemd-journal-upload if the VM sends its logs
        vmname: deploy:
        let isVM = builtins.hasAttr vmname config.naps.topology.vms;
            vmconf = config.naps.topology.vms.${vmname};
            centralizesLogsP = vmconf.centralizeLogs;
            hostsJournaldSink = lib.filter (uid: utils.serviceName config uid == "journald-remote") (vmconf.containers ++ vmconf.services);
        in {
            config.users = utils.mergeAll [
                                (utils.mergeAll (lib.mapAttrsToList mkUser deploy.users))
                                (if isVM && centralizesLogsP && hostsJournaldSink == []
                                    then mkUser "systemd-journal-upload" config.naps.deploy.users."systemd-journal-upload" else {})
                           ];
        };

    mkRoot = vmname: _: {
        config.users.users.root.openssh.authorizedKeys.keys = config.naps.topology.rootSSHPublicKeys;
    };

    addServices =
        srvname: {path, deployements,...}:
        let
            addServiceToDeployement = env:
            {
                ${utils.envUID env}.imports = [path];
            };
        in utils.mergeAll (
                map addServiceToDeployement (builtins.attrValues deployements)
           );
    */
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
