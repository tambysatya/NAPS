{flakeRoot, lib, inputs, config, pkgs,path,...}:

let
    utils = import ../lib {inherit lib inputs;};

    processVM = 
        vmname: {sslCertificates,...}:{
            config = {
                #imports = ["${flakeRoot}/services/step-renew"];
                services.step-renew = {
                    enable = true;
                    caURL = "ca.${config.naps.topology.domain}";
                    caFingerprint = builtins.readFile "${path}/.secrets/git/fingerprint";
                    certs = sslCertificates;
                };
            };
            imports = ["${flakeRoot}/services/step-renew"];
        };
        




in {
    naps.outputs.systems = lib.mapAttrs processVM config.naps.deploy.systems;
}
