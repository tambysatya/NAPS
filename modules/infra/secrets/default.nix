{flakeRoot, lib, inputs, config,...}:
let

    infralib = import "${flakeRoot}/lib" {inherit lib inputs;};
    processSecret = 
        deployementsAttr: 
        secrettype:
        secret: 
        let deployements = builtins.attrValues deployementsAttr;
            additionalRecipients = # adding the hosts of the requested service (to create the access). Note: no need to add openldap since the file will be hashed
                if secrettype == "postgres" then
                   builtins.attrValues config.infra.services.postgres.deployements
                else if secrettype == "s3" then
                   builtins.attrValues config.infra.services.garage.deployements 
                else [];
        in
        if (deployements != []) then
        {
            type=secrettype;
            content=secret;
            recipients = lib.unique (additionalRecipients ++ deployements);
        } else {};

    processRevProxy = 
        deployementsAttr:
        secret:
        let deployements = map infralib.hostDeployementEnv (builtins.attrValues deployementsAttr); # this secrets are always sent to the hosting vm, never to a container
        in if deployements != [] then
        {
            type = "sslCertificate";
            content = secret // {owner="haproxy";};
            recipients = deployements;
        } else {};
    serviceSecrets = 
        srvname: {deployements, links, store, endpoints, ...}: 
        let
            plain = store.plain;
            passwords = store.passwords;

            revproxies = lib.filter (builtins.getAttr "tls") endpoints.http;
            certs = store.sslCertificates; # ++ map (l: l // {owner="haproxy";}) revproxies;

            postgres = links.postgres;
            ldap = links.ldap;
            s3 = links.s3;
        in  map (processSecret deployements "plain") plain
        ++  map (processSecret deployements "password") passwords
        ++  map (processSecret deployements "sslCertificate") certs
        ++  map (processSecret deployements "postgres") postgres
        ++  map (processSecret deployements "ldapssha") ldap
        ++  map (processSecret deployements "s3") s3
        ++  map (processRevProxy deployements) revproxies
        ++  (if srvname == "step-ca"
                then [(processSecret deployements "step-ca" null)] 
                else []);

    deployedServices = lib.filterAttrs (_: {deployements,...}: deployements != {}) config.infra.services;
    allSecrets= lib.unique (lib.concatLists (lib.mapAttrsToList serviceSecrets deployedServices));
    allEnvs = lib.unique (lib.concatMap (srv: builtins.attrValues srv.deployements) (builtins.attrValues deployedServices));

    groupByVM =
        secret@{recipients, ...}:
        let process = env: {
                ${infralib.envHost env} = [secret];
            };
        in infralib.mergeAll (map process recipients);

    vmSecrets = infralib.mergeAll (map groupByVM allSecrets);
    
            
in {
    imports = [./options];
    config.infra.secrets = { 
        allEnvs = allEnvs;
        inherit allSecrets;
        perVM = vmSecrets;
    };
}
