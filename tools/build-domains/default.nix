{flakeRoot, lib,inputs, pkgs, naps, path, ...}:

let
    utils = import ./lib.nix {inherit flakeRoot lib inputs pkgs path;};
    domain = naps.topology.domain;
    
    script = 
        ''
            mkdir -p .secrets/provisioner/ssl


            
            ${utils.gen_ssl_certificate naps.topology.provisionerHost}


            ${lib.concatMapStringsSep "\n" utils.ship (builtins.attrNames naps.topology.vms)}


            # Generate the terranix configuration
            nix build ${path}#terranix -o terraform.tf.json.tmp
            cp terraform.tf.json.tmp terraform.tf.json
            chmod u+w terraform.tf.json
            rm terraform.tf.json.tmp

            #Replace the tokens with their value
            ${lib.concatMapStringsSep "\n" (utils.applyToken "terraform.tf.json") (builtins.attrNames naps.topology.vms)}
        '';



in {
   buildDomains = pkgs.writeShellApplication {
        name = "buildDomains";
        runtimeInputs = [
            pkgs.openssl
            pkgs.step-cli
            pkgs.gzip
        ];
        text = script;
   };
}
