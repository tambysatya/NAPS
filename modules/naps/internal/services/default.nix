{flakeRoot, lib, inputs, config,...}:

let
    utils = import "${flakeRoot}/lib" {inherit lib inputs;};

    /* Should be replaced by a function consulting config.naps.envs.service.<serviceuid> */




    processInstance =
        srvuid: srv@{deployement, is, ...}:{ 
            ${is}.instances.${srvuid} = srv;
        };
    copyService =  #copy the service declaration (from naps.services to naps.internal.services)
        srvname: srvconf: {${srvname} = srvconf;};

    generateAsset = 
        srvname: srvconf: {};


in {
    imports = [
        ./options
    ];
    naps.services = lib.mkMerge (lib.mapAttrsToList processInstance config.naps.internal.envs.instances);
}
