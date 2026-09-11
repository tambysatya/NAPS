{flakeRoot, lib, inputs, config, ...}:

let
    utils = import ./lib {inherit lib inputs flakeRoot;};

    add = name: accesses: env: {
        ${utils.envUID env}.${name} = map (access: {inherit env access;}) accesses;
    };

    processService = 
        _: {deployements, links,...}:
        utils.mergeAll [
            (utils.mergeAll (map (add "s3" links.s3) (builtins.attrValues deployements)))
            (utils.mergeAll (map (add "postgres" links.postgres) (builtins.attrValues deployements)))
        ];


in {
    imports = [./options];
    infra.links =
        utils.mergeAll (lib.mapAttrsToList processService config.infra.services);
}
