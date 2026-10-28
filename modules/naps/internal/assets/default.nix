{flakeRoot, lib, inputs, config, path, pkgs,...}:
let

    utils = import "${flakeRoot}/lib" {inherit lib inputs;} // import "${flakeRoot}/modules/naps/assets/lib" {inherit lib inputs path pkgs flakeRoot;};
   
            
    domain = config.naps.topology.domain;

    mkInstallerForEnv = 
        envname: envassets:
        let 
            namedlist = lib.mapAttrsToList (k: v: v // {name=k;}) envassets; # [{name, provider, ..}]
            byprovider = lib.groupBy (builtins.getAttr "provider") namedlist; # {provider => [{name, provider, ...}]}
            byproviderbyname = lib.mapAttrs 
                                    (_: vs: 
                                        utils.mergeAll 
                                            (lib.map (v: {${v.name} = {inherit (v) generateArgs installArgs reload;};}) vs))
                                    byprovider;
        in byproviderbyname;

    generateScript = 
        let generateAsset =
                genFun: acc: assetname: {args, recipients}:
                    genFun acc assetname args ++ [(utils.give assetname recipients)];
            processProvider =
                acc: providername: assets:
                let provider = config.naps.assets.${providername};
                    genFun = provider.apply.generate;
                in lib.foldlAttrs (generateAsset genFun) acc assets;
        in lib.concatStringsSep "\n" (lib.foldlAttrs processProvider [] config.naps.internal.assets.generator);

    installScript = 
        let 
            installAsset = installFun: args: 
                lib.concatMapStringsSep "\n" installFun args;
            processProvider = 
                providername: assets:
                let provider = config.naps.assets.${providername};
                    installFun = provider.apply.install;
                in lib.concatStringsSep "\n"
                        (lib.mapAttrsToList installFun assets);
            processVM = 
                vmname: assetskinds:
                let scriptsPerProviders = lib.mapAttrsToList processProvider assetskinds; 
                in ''
                    install -d -m 0711 -o root -g root "$PREFIX"${utils.paths.secrets}
                    ${lib.concatStringsSep "\n" scriptsPerProviders}
                '';
        in lib.mapAttrs processVM config.naps.internal.assets.installer;



    /*
    processLinks = env: links@{ldap, postgres, s3}:
        let 
            ldaphosts = builtins.attrValues config.naps.internal.services.openldap.deployements;
            s3hosts = builtins.attrValues config.naps.internal.services.garage.deployements;
            dbhosts = builtins.attrValues config.naps.internal.services.postgres.deployements;

            mkSharedSecret =
                hosts: 
                hostsOwner:  # service user running on the host (e.g. postgres, garage...) 
                hostsReload: # services on the host that depends on the secret
                secretname:
                secret:
                let uid = utils.envUID env;
                    override = {
                        installArgs = {
                            group = hostsOwner;
                            mode = "440";
                            reload = hostsReload;
                        };
                    };
                    mkHostSecret = host: {${utils.envUID host}.${secretname} =(secret // override);}; #replace the owner of the secret transmitted to the hosts
                    dsts = lib.filter (name: name != uid) hosts;
                in utils.mergeAll 
                        ([{${uid}.${secretname} = secret; }] ++ map mkHostSecret dsts);
            processLDAP = access:  #TODO the service reload is not corect
                mkSharedSecret ldaphosts "openldap" ["openldap.service"] (utils.ldap_key access) {provider = "ldapssha"; installArgs = { owner = access.owner;}; generateArgs = access; inherit (access) reload;};
            processPostgres = access:
                let 
                    installArgs = {inherit (access) owner;};
                    secret =  {provider = "postgres"; inherit installArgs; generateArgs = access; inherit (access) reload;};
                in mkSharedSecret dbhosts "postgres" ["postgresql-password.service"] (utils.db_key access) secret;
            processS3 = access:
                mkSharedSecret s3hosts "garage" ["garage-bootstrap.service"]  (utils.s3_root access) {provider = "s3"; installArgs = {owner = access.owner;}; generateArgs = access; inherit (access) reload;};
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
                let cert = {provider = "tls"; installArgs = {owner = "haproxy"; sslFormat="haproxy";}; generateArgs = {inherit hostname;}; reload = ["haproxy.service"];};
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
            #(processEndpoints env endpoints)
            #(processLinks env links)
            (processAssets env assets)
        ];
        
    processService = 
        srvname: srv@{deployements, ...}:
        utils.mergeAll (map (processDeployement srv) (builtins.attrValues deployements));

    */
    applyMerge =
        type: value:
        if type == null then value else type.merge [] [{inherit value; file = "modules.naps.internal.assets.default";}];
    checkAsset = 
        provider: {generateArgs, installArgs, reload}:
        let 
            inputs = config.naps.assets.${provider}.inputs;
            generateArgs' = applyMerge inputs.generateArgs generateArgs;
            installArgs' = applyMerge inputs.installArgs installArgs;
        in {inherit reload; generateArgs=generateArgs'; installArgs=installArgs';};

    processAsset = 
        provider: 
        recipientsUID: # [EnvUID] : list of recipients
        assetname: asset:
        let 
            asset' = checkAsset provider asset;
        in
        {
            all.${provider}.${assetname} = asset';
            recipients.${provider}.${assetname} = recipientsUID;
            perEnv = lib.mkMerge (map (uid: {${uid}.${provider}.${assetname} = asset';})  recipientsUID);
        };

    processProvider =
        recipientsUID: # [EnvUID]: list of recipients. Assumed to be the same for all the assets
        provider: 
        assets:
        let
        in lib.mkMerge 
                (lib.mapAttrsToList 
                    (processAsset provider recipientsUID)  
                 assets);

    processAssets =
        allassets: insname: ins:
        lib.mkMerge (lib.mapAttrsToList (processProvider [(utils.insEnvUID ins)]) allassets);
  
    processEndpoints =
        allendpoints: insname: ins:
        let
            processEndpointType =
                endpointType: endpoints:
                let generateAssets = config.naps.endpoints.${endpointType}.generateAssets;
                    allEndpointAssets = lib.foldl' (attrs: attrs': attrs // attrs') {} (map (ep: generateAssets ep (utils.insEnv ins)) endpoints);
                in lib.mkMerge 
                        (utils.concatMapAttrsToList 
                            (provider: endpointAssets: 
                                lib.mapAttrsToList
                                    (assetname: endpointAsset@{asset, recipients}:
                                        processAsset provider recipients assetname asset)
                                    endpointAssets)
                            allEndpointAssets);
                        
        in lib.mkMerge (lib.mapAttrsToList processEndpointType allendpoints); 

    processLinks =
        alllinks: insname: ins:
        let
            processLinkType =
                linktype: accesses:
                let hosts = lib.mapAttrsToList (inshost: host: utils.insEnv host) config.naps.internal.links.all.${linktype}.providers;
                    generateAsset = config.naps.links.${linktype}.assets;
                    allLinkAssets_ = map (generateAsset (utils.insEnv ins) hosts) accesses;
                    allLinkAssets = lib.foldl' (attrs: attrs': attrs //attrs') {} allLinkAssets_;
                in lib.mkMerge 
                        (utils.concatMapAttrsToList 
                            (provider: linkAssets:
                                lib.mapAttrsToList
                                    (assetname: linkAsset@{asset, recipients}:
                                        processAsset provider recipients assetname asset)
                                    linkAssets)
                            allLinkAssets);
        in lib.mkMerge (lib.mapAttrsToList processLinkType alllinks);
        
    processService = 
        srvname: {instances, assets, links, endpoints,...}:
        let
            stdAssets = lib.mapAttrsToList (processAssets assets) instances;
            endpointsAssets = lib.mapAttrsToList (processEndpoints endpoints) instances;
            linksAssets = lib.mapAttrsToList (processLinks links) instances;
        in lib.mkMerge (stdAssets ++ endpointsAssets ++ linksAssets);

    

in {
    imports = [
        ./options  
    ];
    naps.internal.assets = lib.mkMerge (lib.mapAttrsToList processService config.naps.internal.services);

    /*
    naps.internal.assets.perEnv = perEnv;
    naps.internal.assets.generator = lib.mapAttrs  
                                          (_: assets: # {uid, assetname, env} => uid = {assetname, recipient=[env]}
                                                utils.mergeAll (map ({name, generateArgs, env, ...}: {${name} = {args = generateArgs; recipients=[env];}; }) assets) )
                                            assetsPerType;
    naps.internal.assets.installer = 
        utils.mergeAll (lib.mapAttrsToList (envname: envassets: { ${utils.envHost (getEnv envname)} = mkInstallerForEnv envname envassets;}) config.naps.internal.assets.perEnv);
    naps.internal.assets.scripts = {
        generate = ''
            set -euo pipefail
            mkdir -p ${utils.paths.out} ${utils.paths.git}

                            
            # Initializes the perVM repository
            ${lib.concatMapStringsSep 
                "\n"
                (vmname:
                    ''
                    [[ -d ${utils.paths.perVM}/${vmname} ]] && rm -R ${utils.paths.perVM}/${vmname}
                    mkdir -p ${utils.paths.perVM}/${vmname}
                    echo ${vmname} > ${utils.paths.perVM}/${vmname}/FLAKE
                    '')
                (builtins.attrNames config.naps.internal.assets.installer)}
            
            # Generates the secrets
            ${generateScript}

            # Generates the provisioner tls certificates
            mkdir -p .secrets/provisioner/{ssl,secrets,mtls}
            rm -Rf .secrets/provisioner/ssl/* #clean the repository
            ${lib.concatStringsSep "\n" 
                (config.naps.assets.tls.apply.generate
                    [] "vm-provisioning.${domain}"
                    {hostname=config.naps.topology.provisioner.hostname;})}
            cp .secrets/git/root_ca.crt .secrets/provisioner/ssl/
            mv .secrets/out/${config.naps.topology.provisioner.hostname}/* .secrets/provisioner/ssl/

        '';
        install = installScript;
    };
    */
}
