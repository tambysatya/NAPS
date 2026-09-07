{flakeRoot, lib, inputs, config, pkgs,path,...}:

let
    utils = import ../lib {inherit lib inputs;};

    processVM = 
        vmname: {sslCertificates,...}:{
            config = {
                #imports = ["${flakeRoot}/services/step-renew"];
                services.step-renew = {
                    enable = true;
                    caURL = "ca.${config.infra.topology.domain}";
                    caFingerprint = "${path}/.secrets/git/fingerprint";
                    certs = sslCertificates;
                };
            };
            imports = ["${flakeRoot}/services/step-renew"];
        };
        




in {
    infra.outputs.systems = lib.mapAttrs processVM config.infra.deploy.systems;
}
