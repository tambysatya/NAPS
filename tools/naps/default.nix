{flakeRoot, inputs, lib, pkgs, path, ...}:
let 

   utils = builtins.readFile ./scripts/utils.sh;
   naps = builtins.readFile ./scripts/naps.sh;

in pkgs.writeShellApplication {
    name ="naps";

    runtimeInputs = with pkgs; [
        jq
        openssh
        opentofu
    ];
    text = ''
        set -x
        ${utils}
        ${naps}
    '';
}



