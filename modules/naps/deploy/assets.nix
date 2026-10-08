{flakeRoot, lib, inputs, config, ...}:

let utils = import ./lib.nix {inherit lib inputs flakeRoot;};

    extractCert = 
        {generateArgs, reload, installArgs, ...}: 
            {
                inherit (generateArgs) hostname; 
                inherit (installArgs) sslFormat;
                inherit reload;
            };

    provisionerHost = config.naps.topology.provisioner.hostname;
    provisionerips = config.naps.topology.provisioner.ips;
    mkBackendEnv = port: ip: {
                                env = {
                                    host = provisionerHost;
                                    type = "vm";
                                };
                                inherit ip port;
                            };
    mkProvisionerProxy = port: ips: {
                                backends = map (mkBackendEnv port) ips;
                                frontend = {
                                    hostname = provisionerHost;
                                    public = false;
                                };
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

                    proxy.tcp = {
                        "8080" = mkProvisionerProxy 8080 provisionerips;
                        "8081" = mkProvisionerProxy 8081 provisionerips;
                    };
                })
            config.naps.assets.installer;
}
