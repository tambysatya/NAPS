{flakeRoot, lib, inputs, pkgs, config, path, ...}:

let

    utils = import ../../deploy/lib.nix {inherit inputs lib flakeRoot;};

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
in

{
    imports = [./step.nix
               ./volumes.nix
               ./network.nix
               ./proxy.nix
               ./links.nix # services dependency
               ./logs.nix
              ];
    #naps.outputs = utils.mergeAll (lib.mapAttrsToList processSystem config.naps.deploy.systems);
    naps.outputs.systems = 
        utils.mergeAll [
            (lib.mapAttrs processUsers config.naps.deploy.systems)
            (lib.mapAttrs mkRoot config.naps.deploy.systems)
            (utils.mergeAll (lib.mapAttrsToList addServices config.naps.services))
        ];
}
