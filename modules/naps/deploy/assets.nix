{flakeRoot, lib, inputs, config, ...}:

let utils = import ./lib.nix {inherit lib inputs flakeRoot;};

    extractCert = 
        {generateArgs, reload, installArgs, ...}: 
            {
                inherit (generateArgs) hostname; 
                inherit (installArgs) format;
                inherit reload;
            };

in
{
     naps.deploy.systems = 
        lib.mapAttrs 
            (vmname: 
             assets@{tls ? {},...}:
                {
                    sslCertificates = 
                        map extractCert (builtins.attrValues tls); 
                })
            config.naps.assets.installer;
}
