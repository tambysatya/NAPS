{flakeRoot, lib, inputs, config,...}:
let

    utils = import "${flakeRoot}/lib" {inherit lib inputs;};
   
            
    domain = config.naps.topology.domain;

    processLinks = env: links@{ldap, postgres, s3}:
        let 
            ldaphosts = builtins.attrValues config.naps.services.openldap.deployements;
            s3hosts = builtins.attrValues config.naps.services.garage.deployements;
            dbhosts = builtins.attrValues config.naps.services.postgres.deployements;

            mkSharedSecret =
                hosts: 
                hostsOwner:  # service user running on the host (e.g. postgres, garage...) 
                secretname:
                secret:
                let uid = utils.envUID env;
                    mkHostSecret = host: {${utils.envUID host}.${secretname} =(secret // {owner=hostsOwner;});}; #replace the owner of the secret transmitted to the hosts
                    dsts = lib.filter (name: name != uid) hosts;
                in utils.mergeAll 
                        ([{${uid}.${secretname} = secret; }] ++ map mkHostSecret dsts);
            processLDAP = access: 
                mkSharedSecret ldaphosts "openldap" (utils.ldap_key access) {provider = "ldapssha"; owner = access.owner; args=access;};
            processPostgres = access:
                mkSharedSecret dbhosts "postgres" (utils.db_key access) {provider = "postgres"; owner = access.owner; args=access;};
            processS3 = access:
                mkSharedSecret dbhosts "garage" (utils.s3_root access) {provider = "s3"; owner = access.owner; args=access;};
        in utils.mergeAll (
                map processLDAP ldap ++
                map processPostgres postgres ++
                map processS3 s3);

    processEndpoints = env: endpoints: {};
    processAssets = env: assets: {};
    
    processDeployement = 
        srv@{endpoints, links, assets, ...}:
        env:
        utils.mergeAll [
            (processEndpoints env endpoints)
            (processLinks env links)
            (processAssets env assets)
        ];
        
    processService = 
        srvname: srv@{deployements, ...}:
        utils.mergeAll (map (processDeployement srv) (builtins.attrValues deployements));

in {
    imports = [./options];
    naps.secrets.perEnv = utils.mergeAll (lib.mapAttrsToList processService config.naps.services);
        /*
    config.naps.secrets = { 
        allEnvs = allEnvs;
        inherit allSecrets;
        perVM = vmSecrets;
    };
        */
}
