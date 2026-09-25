{flakeRoot, lib, inputs, config, ...}:

let
    utils = import "${flakeRoot}/lib" {inherit inputs lib;};
    allEnvs = utils.mergeAll (lib.map (builtins.getAttr "deployements") (builtins.attrValues config.naps.services));
    parts = utils.partitionAttrs (_: {type,...}: type == "vm") allEnvs;
    
    
    
    # srvuid is the name of the instance of the service which is the name of the environment
    # ONLY if the service runs within a container. Otherwise, the environment name is the VM
    extractName = srvuid: deploy: {${utils.envUID deploy} = deploy;};
    extractNames = attrs: utils.mergeAll (lib.mapAttrsToList extractName attrs);

in {
    imports = [./options.nix];
    naps.envs.vms = extractNames parts.right;
    naps.envs.containers = extractNames parts.wrong;
    naps.envs.all = extractNames allEnvs;
}
