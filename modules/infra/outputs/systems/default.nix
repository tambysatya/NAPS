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
    processUsers = 
        name: deploy:
        {
            config.users = utils.mergeAll (lib.mapAttrsToList mkUser deploy.users);
        };

    mkRoot = vmname: _: {
        config.users.users.root.openssh.authorizedKeys.keys = config.infra.topology.rootSSHPublicKeys;
    };

    addServices =
        srvname: {deployements,...}:
        let
            addServiceToDeployement = env:
            {
                ${utils.envUID env}.imports = ["${flakeRoot}/services/${srvname}"];
            };
        in utils.mergeAll (map addServiceToDeployement (builtins.attrValues deployements));
in

{
    imports = [./step.nix
               ./volumes.nix
               ./network.nix
               ./proxy.nix
               ./links.nix # services dependency
               ./logs.nix
              ];
    #infra.outputs = utils.mergeAll (lib.mapAttrsToList processSystem config.infra.deploy.systems);
    infra.outputs.systems = 
        utils.mergeAll [
            (lib.mapAttrs processUsers config.infra.deploy.systems)
            (lib.mapAttrs mkRoot config.infra.deploy.systems)
            (utils.mergeAll (lib.mapAttrsToList addServices config.infra.services))
        ];
}
