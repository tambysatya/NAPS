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
    provisionermtls = config.naps.topology.provisioner.ports.mtls;
    mkBackendEnv = port: ip: {
                                env = {
                                    host = provisionerHost;
                                    type = "vm";
                                    priority = 100;
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
                        "${lib.toString provisionermtls}" = mkProvisionerProxy provisionermtls provisionerips;  #we add the mTLS endpoint
                    };
                })
            config.naps.assets.installer;
}
