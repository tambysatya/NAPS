{flakeRoot, lib, inputs, config, ...}:

let utils = import ./lib.nix {inherit lib inputs flakeRoot;};

    processStore = 
        store@{passwords, sslCertificates,...}:
        env:
            utils.mergeAll 
                (map (processPasswords env) passwords
                ++ map (processCertificates env) sslCertificates);
    processPasswords =
        env:
        pass: 
        {
            ${utils.envUID env}.secrets = [{inherit (pass) filename owner mode;}];
        };
    processCertificates = 
        env:
        cert@{hostname,...}:
        let crt = "${hostname}.crt";
            key = "${hostname}.key";
        in {
            ${utils.envUID env} = {
                secrets = [{filename=crt; mode="0400"; inherit (cert) owner;}
                        {filename=key; mode="0400"; inherit (cert) owner;}];
                sslCertificates = [cert];
            };
        };


    processService = 
        srvname: {deployements, store,...}:
        let envs = builtins.attrValues deployements;
            stepcasecretnames = ["intermediate_ca_key" "ca-password.key"];
            stepcasecrets = map (filename: {inherit filename; owner="root"; mode="0400";}) stepcasecretnames;
            additionalsecrets = env: {${utils.envUID env}.secrets = stepcasecrets;};
        in
        utils.mergeAll (map (processStore store) envs ++ (if srvname == "step-ca" then map additionalsecrets envs else []));

in
{
    naps.deploy.systems = utils.mergeAll (lib.mapAttrsToList processService config.naps.services);
}
