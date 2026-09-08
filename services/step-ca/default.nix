{flakeRoot, lib, inputs, config, pkgs, path,...}:
let 


in {

config =
        {
            services.step-ca = {
                enable = true;
                address = infra.caURL;
                port = infra.caPort;
                openFirewall = true;
                intermediatePasswordFile = "/var/lib/secrets/ca-password.key";
                settings = builtins.fromJSON (builtins.readFile "${path}/.secrets/git/ca.json"); 
            };
        };
        
}
