{flakeRoot, lib, inputs, config, path, pkgs,...}:
let
    utils = import "${flakeRoot}/lib" {inherit lib inputs;} // import "${flakeRoot}/providers/lib" {inherit flakeRoot lib inputs path pkgs;};

in 
{
    imports = [./options];
}
