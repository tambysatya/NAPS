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
    hostHasContainers = env: config.infra.topology.vms.${utils.envHost env}.containers != [];
    getEnvHostIP = env: config.infra.deploy.systems.${utils.envHost env}.ip;
    mkProxy =
        env: name: port: backendsEnv: mode:
        let tcpFrontend = 
                {
                    frontend = {
                        ip = if hostHasContainers env then "192.168.100.1" else "127.0.0.1";
                        inherit port;
                     };
                 };
            udpFrontend = throw "UDP protocol not implemented";
        in {
            ${utils.envHost env}.proxy.${mode}.${name} =
                utils.mergeAll [
                    (if mode == "tcp" then tcpFrontend else if mode == "udp" then udpFrontend else {})
                    { backends = map (env: {ip=getEnvHostIP env; inherit port; inherit env;}) backendsEnv;}
                ];
        };


    processLdap =
        env: ldap:
        let secret = {inherit (ldap) filename owner reload mode;};
        in mkSharedSecret env ldaphosts "openldap" secret // mkProxy env "ldap.${domain}" 636 ldaphosts "tcp"; 
    processS3 = 
        env: access:
        let id = {filename=utils.s3_key_id access; inherit (access) owner; mode="0400";};
            key = {filename=utils.s3_key access; inherit (access) owner; mode="0400";};

        in utils.mergeAll 
                [(mkSharedSecret env s3hosts "garage" id)
                 (mkSharedSecret env s3hosts "garage" key)
                 (mkProxy env "s3.${domain}" 443 s3hosts "http")];
    processPostgres = 
        env: access: 
        let secret = {filename = utils.db_key access; inherit (access) owner; mode="0400";};
        in mkSharedSecret env dbhosts "postgres" secret //
           mkProxy env "postgres.${domain}" 5432 dbhosts "tcp";
in {
    infra.deploy.systems = utils.mergeAll (lib.mapAttrsToList processService config.infra.services);
}
