{flakeRoot, lib, inputs, config, pkgs, path, naps,...}:
let 


in {

config =
        {
            services.step-ca = {
                enable = true;
                address = "ca.${naps.topology.domain}";
                port = 8443;
                openFirewall = true;
                intermediatePasswordFile = "/var/lib/secrets/ca-password.key";
                settings = builtins.fromJSON (builtins.readFile "${path}/.secrets/git/ca.json"); 
            };
        };
        
}
