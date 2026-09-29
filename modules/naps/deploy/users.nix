{flakeRoot, lib, inputs, config, ...}:

let
    utils = import ./lib.nix {inherit lib inputs flakeRoot;};

    haproxy= {service = "haproxy"; uid=9999;};
    step-renew = {service = "step-renew"; uid=9998;};
    users = utils.mergeAll (map (builtins.getAttr "users") (builtins.attrValues config.naps.services)) // {inherit haproxy step-renew;};
    



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
    addStepRenew = envuid: {${envuid}.users.step-renew= step-renew;};


in {
    naps.deploy.users = users;
    naps.deploy.systems =
        utils.mergeAll 
            (map processService (builtins.attrValues config.naps.services)
            ++ map addHaproxy (builtins.attrNames config.naps.topology.vms)
            ++ map addStepRenew (builtins.attrNames config.naps.envs.all));
}
