{flakeRoot, lib,inputs, pkgs, naps, path, ...}:

let
    utils = import ./lib.nix {inherit flakeRoot lib inputs pkgs path;};
    domain = naps.topology.domain;
    
    script = 
        ''

            if ! [[ -e .secrets/git/root_ca.crt ]]; then
                echo "No PKI interface found. Please run the asset-generator before"
                exit 1
            fi

           


            ${lib.concatMapStringsSep "\n" utils.ship (builtins.attrNames naps.topology.vms)}


            # Generate the terranix configuration
            nix build ${path}#terranix -o terraform.tf.json.tmp

            cp terraform.tf.json.tmp terraform.tf.json
            chmod u+w terraform.tf.json
            rm terraform.tf.json.tmp

            #Replace the tokens with their value
            ${lib.concatMapStringsSep "\n" (utils.applyToken "terraform.tf.json") (builtins.attrNames naps.topology.vms)}

            #Replace the iso name
            ISO_NAME=$(ls result/iso/*.iso)
            echo "ISO_NAME=$ISO_NAME"
            sed -i "s+ISO_NAME+$ISO_NAME+" "terraform.tf.json" 
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
