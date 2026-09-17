{inputs, lib, naps, vmname,  ...}:
    

/* Basic security management: Secrets, TLS certificates and reverse proxys */

let 

    vars = import "${inputs.self.outPath}/lib/vars.nix" {inherit lib naps inputs;};
    # Generate the sops options for an attrset of secrets (same owner, same reloadUnit
    generateSecret = 
      secret:
          lib.mkMerge 
            (lib.map
                (name:
                      let secretFile = "${naps.flakePath}/${vars.enc}/${vmname}-${name}.enc";
                      in {

                        sops.age.keyFile = "/var/lib/sops-nix/key.txt";
                        sops.secrets."${name}" = {
                            sopsFile = secretFile;
                            format = "binary";
                            owner = secret.owner or "root";
                            restartUnits = secret.reload;
                            mode = secret.mode or "0400";
                         };
                      }
                )
                secret.names);

   /* Generates the secret and the auto-refresh service for a given certificate.
      registerCertificate : vmname -> owner -> serviceunit -> NixosConfig

      - the servicename (different from the unit) is of type "servicetype".
        It will be used to have a different behavior regarding how the service is deployed
        (e.g. if deployed within a nixos-container, the secret will also be bindmount)
      - the encrypted secret must have name certname.{crt,key}.enc
      - the secret will be stored in /var/lib/owner/certname.{crt,key}
      - the reload units are set to [ serviceunit ]
    */

    generateCertificate =
       servicename: certname: sslcert:
       let
            secret = {
                names = ["${certname}.crt" "${certname}.key"];
                inherit (sslcert) owner reload;
            };
       in
          lib.mkMerge [
           (generateSecret secret) 
           {
                services.step-renew = {
                    enable = true;
                    caURL = "${naps.caURL}:${lib.toString naps.caPort}";
                    caFingerprint = builtins.readFile "${naps.flakePath}/${vars.git}/fingerprint";
                    certs."${certname}" = {inherit (sslcert) owner reload;};
                };
           }];

    generateReverseProxy =
        {fronthost, backhost, extraNginxConfig ? {}}: 
        let

        in lib.mkMerge [
            (generateCertificate "nginx" fronthost 
                {
                    reload = ["nginx.service"];
                    owner = "nginx";
                })
            {
                networking.firewall.allowedTCPPorts = [80 443];
                services.nginx = lib.mkMerge [
                    {
                        enable = true;
                        virtualHosts."${fronthost}" ={
                            sslCertificate = vars.ssl_crt_path fronthost;
                            sslCertificateKey = vars.ssl_key_path fronthost;
                            forceSSL = true;

                            locations."/" = {
                                proxyPass = backhost;
                                extraConfig = ''
                                      proxy_set_header Host $host;
                                      proxy_set_header X-Forwarded-Host $host;
                                      proxy_set_header X-Forwarded-Proto $scheme;
                                      proxy_set_header X-Forwarded-Port $server_port;
                                      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

                                  '' ;

                            };
                        };
                    }
                    extraNginxConfig];
            }
            ];

in {
    inherit generateSecret generateCertificate generateReverseProxy;
}
