{flakeRoot, lib, inputs, pkgs, config, path, ...}:

let

    utils = import ../../deploy/lib.nix {inherit inputs lib flakeRoot;};

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
    proxyConfigs = 
        let
            processProxy = envuid: str: {config.services.haproxy.config = str;};
        in lib.mapAttrs processProxy config.naps.internal.endpoints.outputs.proxy;
    networkConfig = 
        let
            processIR = 
                envuid: ir: 
                let
                    env = config.naps.internal.environments.all.${envuid};
                in 
                {};
        in {};
in

{
    imports = [
               #./volumes.nix
               #./network.nix
              ];
    naps.outputs.systems = lib.mkMerge [
        config.naps.internal.assets.outputs.config # assets services (e.g. step-renew for TLS refresh)
        config.naps.internal.links.outputs # dependencies across the infrastructure (e.g. wait-uplinks services)
        proxyConfigs # haproxy configuration of VMs
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
