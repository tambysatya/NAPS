{flakeRoot, lib, inputs, config,...}:

let
    utils = import "${flakeRoot}/lib" {inherit lib inputs;};

    /* Should be replaced by a function consulting config.naps.envs.service.<serviceuid> */

in {
   imports = [./options];
}
