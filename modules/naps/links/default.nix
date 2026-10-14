{flakeRoot, lib, inputs, config, ...}:

let
    utils = import ./lib {inherit lib inputs flakeRoot;};

in {
    imports = [./options];
    naps.links = {};
}
