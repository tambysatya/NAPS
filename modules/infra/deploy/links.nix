{flakeRoot, lib, inputs, config, ...}:

let utils = import ./lib.nix {inherit lib inputs flakeRoot;};

    processService =
        _:
        {deployements, links,...}:
        utils.mergeAll (lib.concatMap (processLinks links) (builtins.attrValues deployements));

    processLinks =
        {ldap, s3, postgres}:
        env:
        map (processLdap env) ldap 
        ++ map (processS3 env) s3
        ++ map (processPostgres env) postgres;

    domain = config.infra.topology.domain;
    ldaphosts = builtins.attrValues config.infra.services.openldap.deployements;
    s3hosts = builtins.attrValues config.infra.services.garage.deployements;
    dbhosts = builtins.attrValues config.infra.services.postgres.deployements;


    mkSharedSecret =
        env: hosts: 
        hostsOwner:  # service user running on the host (e.g. postgres, garage...) 
        secret:
        let uid = utils.envUID env;
            mkHostSecret = host: {${utils.envUID host}.secrets=[(secret // {owner=hostsOwner;})];}; #replace the owner of the secret transmitted to the hosts
            dsts = lib.filter (name: name != uid) hosts;
        in utils.mergeAll 
                ([{${uid}.secrets = [secret]; }] ++ map mkHostSecret dsts);


    processLdap =
        env: ldap:
        let secret = {inherit (ldap) filename owner mode;};
        in mkSharedSecret env ldaphosts "openldap" secret; 
    processS3 = 
        env: access:
        let id = {filename=utils.s3_key_id access; inherit (access) owner; mode="0400";};
            key = {filename=utils.s3_key access; inherit (access) owner; mode="0400";};

        in utils.mergeAll 
                [(mkSharedSecret env s3hosts "garage" id)
                 (mkSharedSecret env s3hosts "garage" key)];
    processPostgres = 
        env: access: 
        let secret = {filename = utils.db_key access; inherit (access) owner; mode="0400";};
        in mkSharedSecret env dbhosts "postgres" secret;
in {
    infra.deploy.systems = utils.mergeAll (lib.mapAttrsToList processService config.infra.services);
}
