{flakeRoot, lib, inputs, config, ...}:

let
    utils = import ./lib.nix {inherit lib inputs flakeRoot;};

    haproxy= {service = "haproxy"; uid=9999;};
    users = utils.mergeAll (map (builtins.getAttr "users") (builtins.attrValues config.naps.services)) // {inherit haproxy;};
    



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

    addHaproxy = vmname: {${vmname}.users.haproxy = haproxy;};


in {
    naps.deploy.users = users;
    naps.deploy.systems =
        utils.mergeAll 
            (map processService (builtins.attrValues config.naps.services)
            ++ map addHaproxy (builtins.attrNames config.naps.topology.vms));
}
