{flakeRoot, lib, inputs, config, ...}:

let
    utils = import "${flakeRoot}/lib" {inherit inputs lib;};
    allEnvs = utils.mergeAll (lib.map (builtins.getAttr "deployements") (builtins.attrValues config.naps.services));
    parts = utils.partitionAttrs (_: {type,...}: type == "vm") allEnvs;
in {
    imports = [./options.nix];
    naps.envs.vms = parts.right;
    naps.envs.containers = parts.wrong;
}
