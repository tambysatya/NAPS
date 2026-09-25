{flakeRoot, lib, inputs, config,...}:
let

    utils = import "${flakeRoot}/lib" {inherit lib inputs;};
   
            

    processEndpoints = env: endpoints: {};
    processLinks = env: links: {};
    processAssets = env: assets: {};
    
    processDeployement = 
        srv@{endpoints, links, assets, ...}:
        env:
        utils.mergeAll [
            (processEndpoints env endpoints)
            (processLinks env links)
            (processAssets env assets)
        ];
        
    processService = 
        srvname: srv@{deployements, ...}:
        utils.mergeAll (map (processDeployement srv) (builtins.attrValues deployements));

in {
    imports = [./options];
    config.naps.secrets = { 
        /*
        allEnvs = allEnvs;
        inherit allSecrets;
        perVM = vmSecrets;
        */
    };
}
