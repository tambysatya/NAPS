{flakeRoot, inputs, lib, pkgs, path, ...}:
let 

   vars = builtins.readFile ./scripts/vars.sh;
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
        
        ${utils}
        ${vars}

        ${naps}
    '';
}



