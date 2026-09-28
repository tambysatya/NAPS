{flakeRoot, lib, inputs, config, ...}:

let utils = import ./lib.nix {inherit lib inputs flakeRoot;};

    extractCert = 
        {generateArgs, reload, ...}: {inherit (generateArgs) hostname; inherit reload;};

in
{
     naps.deploy.systems = 
        lib.mapAttrs 
            (vmname: 
             assets@{tls ? {}, haproxy ? {},...}:
                {
                    sslCertificates = 
                        (map extractCert (builtins.attrValues tls) ++
                         map extractCert (builtins.attrValues haproxy));
                })
            config.naps.assets.installer;
}
