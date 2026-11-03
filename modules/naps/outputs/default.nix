{flakeRoot, lib, inputs, pkgs, config, path, ...}:

let

    utils = import ./lib {inherit inputs lib flakeRoot;};

in

{
    imports = [./options
               ./systems
               ./domains
               ./iso.nix
              ];
    #naps.outputs = utils.mergeAll (lib.mapAttrsToList processSystem config.naps.deploy.systems);
    #naps.outputs.systems = lib.mapAttrs defaultConf config.naps.topology.vms;
}
