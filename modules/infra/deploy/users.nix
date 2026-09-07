{flakeRoot, lib, inputs, config, ...}:

let
    utils = import ./lib.nix {inherit lib inputs flakeRoot;};
    users = lib.concatMap (builtins.getAttr "users") (builtins.attrValues config.infra.services) ++ [{name = "haproxy"; uid=9999;}];
    assertUsers =
        let dupUser = utils.getFirstDupplicate (map (builtins.getAttr "name" (lib.unique users)));
        in {
            assertion = dupUser == null;
            message = "Dupplicate users: ${dupUser} has two different userIDs";
        };

    processService=
        {deployements, users,...}:
        let processDeployement = env:
            utils.mergeAll [
                {${utils.envUID env}.users = users;}
                (if env.type == "container"
                    then {${utils.envHost env}.users = users;}
                    else {})
            ];
        in utils.mergeAll (map processDeployement (builtins.attrValues deployements));


in {
    assertions = [assertUsers];
    infra.deploy.users = lib.unique users;
    infra.deploy.systems = utils.mergeAll (map processService (builtins.attrValues config.infra.services));
}
