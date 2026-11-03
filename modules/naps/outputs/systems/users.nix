{flakeRoot, lib, inputs, pkgs, config, path, ...}:

let

    utils = import "${flakeRoot}/lib" {inherit inputs lib flakeRoot;};

    mkUser = username: uid:
        {
            users.${username} = {
                uid = lib.mkForce uid;
                group = username;
                isSystemUser = true;
            };
            groups.${username} = {
                gid = lib.mkForce uid;
            };
        };
    mkRoot = vmname: _: {
        ${vmname}.config = {
            users.users.root.openssh.authorizedKeys.keys = config.naps.topology.rootSSHPublicKeys;
            #TODO should we enable ssh per default ?
            networking.firewall.interfaces."enp1s0".allowedTCPPorts = [22]; 
            services.openssh.enable = true;
        };
    };
    processService = 
        srvname: srv@{users, instances,...}:
        let
            processUser = 
                insname: ins: username: {uid, ...}:
                lib.mkMerge [
                    {${utils.insEnvUID ins}.config.users = mkUser username uid;}
                    # If the service runs within a container, the user must be created on the VM as well
                    (lib.optionalAttrs (utils.runsInContainer ins) {
                        ${utils.insHostUID ins}.config.users = mkUser username uid;
                    })
                ];
            processInstance = 
                insname: ins: lib.mkMerge (lib.mapAttrsToList (processUser insname ins) users);
        in lib.mkMerge (lib.mapAttrsToList processInstance instances);

in {
    naps.outputs.systems = 
        lib.mkMerge [
            (lib.mkMerge (lib.mapAttrsToList processService config.naps.internal.services))
            (lib.mkMerge (lib.mapAttrsToList mkRoot config.naps.topology.vms))
        ];
}


