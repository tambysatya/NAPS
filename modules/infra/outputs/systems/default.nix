{flakeRoot, lib, inputs, pkgs, config, path, ...}:

let

    utils = import ../../deploy/lib.nix {inherit inputs lib flakeRoot;};

    mkUser = {name, uid}:
        {
            users.${name} = {
               inherit uid;
               group = name;
               isSystemUser = true;
            };
            groups.${name} = {
                gid = uid;
            };
        };
    processUsers = 
        name: deploy:
        {
            config.users = utils.mergeAll (map mkUser deploy.users);
        };

    mkRoot = vmname: _: {
        config.users.users.root.openssh.authorizedKeys.keys = config.infra.topology.rootSSHPublicKeys;
    };
in

{
    imports = [./step.nix
               ./volumes.nix
               ./network.nix
              ];
    #infra.outputs = utils.mergeAll (lib.mapAttrsToList processSystem config.infra.deploy.systems);
    infra.outputs.systems = 
        utils.mergeAll [
            (lib.mapAttrs processUsers config.infra.deploy.systems)
            (lib.mapAttrs mkRoot config.infra.deploy.systems)
        ];
}
