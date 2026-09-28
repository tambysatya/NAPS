{flakeRoot, lib, inputs, config, path,...}:
let

    utils = import "${flakeRoot}/lib" {inherit lib inputs;} // import ./providers/lib {inherit flakeRoot lib inputs path;};
   
            
    domain = config.naps.topology.domain;

    processLinks = env: links@{ldap, postgres, s3}:
        let 
            ldaphosts = builtins.attrValues config.naps.services.openldap.deployements;
            s3hosts = builtins.attrValues config.naps.services.garage.deployements;
            dbhosts = builtins.attrValues config.naps.services.postgres.deployements;

            mkSharedSecret =
                hosts: 
                hostsOwner:  # service user running on the host (e.g. postgres, garage...) 
                hostsReload: # services on the host that depends on the secret
                secretname:
                secret:
                let uid = utils.envUID env;
                    override = {
                        installArgs = {owner = hostsOwner;};
                        reload = hostsReload;
                    };
                    mkHostSecret = host: {${utils.envUID host}.${secretname} =(secret // override);}; #replace the owner of the secret transmitted to the hosts
                    dsts = lib.filter (name: name != uid) hosts;
                in utils.mergeAll 
                        ([{${uid}.${secretname} = secret; }] ++ map mkHostSecret dsts);
            processLDAP = access: 
                mkSharedSecret ldaphosts "openldap" ["openldap.service"] (utils.ldap_key access) {provider = "ldapssha"; installArgs = { owner = access.owner;}; generateArgs = access; inherit (access) reload;};
            processPostgres = access:
                mkSharedSecret dbhosts "postgres" ["postgresql.service"] (utils.db_key access) {provider = "postgres"; installArgs = {owner = access.owner;}; generateArgs = access; inherit (access) reload;};
            processS3 = access:
                mkSharedSecret s3hosts "garage" ["garage.service"]  (utils.s3_root access) {provider = "s3"; installArgs = {owner = access.owner;}; generateArgs = access; inherit (access) reload;};
        in utils.mergeAll (
                map processLDAP ldap ++
                map processPostgres postgres ++
                map processS3 s3);

    processEndpoints = env: endpoints:
        # only reverse proxy are processed. Otherwise, certificates must be 
        # registered manually in the assets section and handled manually in
        # the configuration
        let
            dst = if env.type == "container" then utils.envUID env else utils.envHost env;
            processHTTPEndpoint  =
                {tls, hostname, ...}:
                let cert = {provider = "haproxy"; installArgs = {owner = "haproxy";}; generateArgs = {inherit hostname;}; reload = ["haproxy.service"];};
                in lib.optionalAttrs tls {${dst}.${hostname} = cert;}; #if TLS=false, the certificate should be declared manually in the assets
        in utils.mergeAll(
                map processHTTPEndpoint endpoints.http);
    processAssets = env: assets: {
        ${utils.envUID env} = assets;
    };
    
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


    perEnv = utils.mergeAll (lib.mapAttrsToList processService config.naps.services); # envUID => assetName => asset
    getEnv = uid: config.naps.envs.all.${uid}; 
    allAssets = # [{uid, assetname, asset}]
        let processEnv = uid: assetsattr: lib.mapAttrsToList (assetname: asset: asset // {name=assetname; env = getEnv uid;} ) assetsattr;
        in lib.concatLists (lib.mapAttrsToList processEnv perEnv);
    assetsPerType = builtins.groupBy (builtins.getAttr "provider") allAssets; # provider => [{uid, assetname, asset}]

    mkInstallerForEnv = 
        envname: envassets:
        let 
            namedlist = lib.mapAttrsToList (k: v: v // {name=k;}) envassets; # [{name, provider, ..}]
            byprovider = lib.groupBy (builtins.getAttr "provider") namedlist; # {provider => [{name, provider, ...}]}
            byproviderbyname = lib.mapAttrs 
                                    (_: vs: 
                                        utils.mergeAll 
                                            (lib.map (v: {${v.name} = {args = v.installArgs;};}) vs))
                                    byprovider;
        in byproviderbyname;



    generateScript = 
        let generateAsset =
                genFun: acc: assetname: {args, recipients}:
                    genFun acc args ++ [(utils.give assetname recipients)];
            processProvider =
                acc: providername: assets:
                let provider = config.naps.assets.providers.${providername};
                    genFun = provider.apply.generate;
                in lib.foldlAttrs (generateAsset genFun) acc assets;
        in lib.concatStringsSep "\n" (lib.foldlAttrs processProvider [] config.naps.assets.generator);

    installScript = 
        let 
            installAsset = installFun: args: 
                lib.concatMapStringsSep "\n" installFun args;
            processProvider = 
                providername: assets:
                let provider = config.naps.assets.providers.${providername};
                    installFun = provider.apply.install;
                in lib.concatMapStringsSep "\n" installFun (builtins.attrValues assets);
            processVM = 
                vmname: assetskinds:
                let scriptsPerProviders = lib.mapAttrsToList processProvider assetskinds; 
                in lib.concatStringsSep "\n" scriptsPerProviders;
        in lib.mapAttrs processVM config.naps.assets.installer;

in {
    imports = [./options ./providers];
    naps.assets.perEnv = perEnv;
    naps.assets.generator = lib.mapAttrs  
                                (_: assets: # {uid, assetname, env} => uid = {assetname, recipient=[env]}
                                    utils.mergeAll (map ({name, generateArgs, env, ...}: {${name} = {args = generateArgs; recipients=[env];}; }) assets) )
                                assetsPerType;
    naps.assets.installer = lib.mapAttrs mkInstallerForEnv config.naps.assets.perEnv;
    naps.assets.script = {
        generate = generateScript;
        install = installScript;
    };
}
