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

    generateAssets = 
        let generateAsset =
                providername: genFun: acc: assetname: {generateArgs,...}:
                    let recipients = config.naps.internal.assets.recipients.${providername}.${assetname};
                    in genFun acc assetname generateArgs ++ [(utils.give config assetname recipients)];
            processProvider =
                acc: providername: assets:
                let provider = config.naps.assets.${providername};
                    genFun = provider.apply.generate;
                in lib.foldlAttrs (generateAsset providername genFun) acc assets;
        in lib.concatStringsSep "\n" (lib.foldlAttrs processProvider [] config.naps.internal.assets.all);
    generateScript = ''
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
            (builtins.attrNames config.naps.internal.envs.vms)}
        # Generates the containers directory within each vm directory
        ${utils.concatMapAttrsStringsSep 
            "\n"
            (ctname: ctenv:
                let vmname = utils.envHostUID ctenv;
                in ''
                [[ -d ${utils.paths.perVM}/${vmname}/${ctname} ]] && rm -R ${utils.paths.perVM}/${vmname}/${ctname}
                mkdir -p ${utils.paths.perVM}/${vmname}/${ctname}
                echo ${ctname} > ${utils.paths.perVM}/${vmname}/${ctname}/FLAKE
                '')
            config.naps.internal.envs.containers}
        
        # Generates the secrets
        ${generateAssets}

        # Generates the provisioner tls certificates
        mkdir -p .secrets/provisioner/{ssl,secrets,mtls}
        rm -Rf .secrets/provisioner/ssl/* #clean the repository
        ${lib.concatStringsSep "\n" 
            (config.naps.assets.tls.apply.generate
                [] "vm-provisioning.${domain}"
                {hostname=config.naps.topology.provisioner.hostname;})}
        cp .secrets/git/root_ca.crt .secrets/provisioner/ssl/
        mv .secrets/out/${config.naps.topology.provisioner.hostname}/*.crt .secrets/provisioner/ssl/crt
        mv .secrets/out/${config.naps.topology.provisioner.hostname}/*.key .secrets/provisioner/ssl/key
    '';

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
            
            processEnv =
                envuid: assetskinds: 
                let scriptsPerProviders = lib.mapAttrsToList processProvider assetskinds; 
                    env = config.naps.internal.envs.all.${envuid};
                    installPrefix = 
                        if utils.isContainer env 
                        then ''"$PREFIX"${utils.paths.secrets}/${envuid}''
                        else ''"$PREFIX"'';
                in ''
                    install -d -m 0711 -o root -g root "$PREFIX"${utils.paths.secrets}${lib.optionalString (utils.isContainer env) "/${envuid}"}
                    ${lib.optionalString (utils.isContainer env) 
                        ''
                            TMP_PREFIX="$PREFIX" 
                            PREFIX="$PREFIX${utils.paths.secrets}/${envuid}"
                        ''}
                    ${lib.concatStringsSep "\n" scriptsPerProviders}
                    ${lib.optionalString (utils.isContainer env) 
                        ''
                            PREFIX=TMP_PREFIX 
                        ''}
                '';
            processVM = 
                vmname: envuids: 
                let scriptsPerProviders = lib.mapAttrsToList processEnv envuids; 
                in ''
                    install -d -m 0711 -o root -g root "$PREFIX"${utils.paths.secrets}
                    ${lib.concatStringsSep "\n" scriptsPerProviders}
                '';
        in lib.mapAttrs processVM config.naps.internal.assets.perVM;


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
        assetname: asset@{installArgs,...}:
        let 
            asset' = checkAsset provider asset;
            asset'' = if builtins.hasAttr "path" installArgs && installArgs.path != null && installArgs.path != ""
                      then asset'
                      else asset' // {installArgs = installArgs // {path = "${utils.paths.secrets}/${assetname}";};};
        in
        {
            all.${provider}.${assetname} = asset'';
            recipients.${provider}.${assetname} = recipientsUID;
            perEnv = lib.mkMerge (map (uid: {${uid}.${provider}.${assetname} = asset'';})  recipientsUID);
            perVM = lib.mkMerge (map (uid: {${utils.envHostUID config.naps.internal.envs.all.${uid}}.${uid}.${provider}.${assetname} = asset'';})  recipientsUID);
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

    # process standard assets
    processAssets =
        allassets: insname: ins:
        lib.mkMerge (lib.mapAttrsToList (processProvider [(utils.insEnvUID ins)]) allassets);

    # Process shipped assets: assets decorated with their recipients (used within links/endpoints description)
    # Map Provider (Map AssetName ShippedAsset) -> {config.naps.internal.assets = MergedState}
    processShippedAssets = 
        allassets:
        utils.concatMapAttrsToList
            (provider: shippedassets:
                lib.mapAttrsToList 
                    (assetname: {asset, recipients}:
                        processAsset provider recipients assetname asset)
                    shippedassets)
            allassets;
  
    # generates a set of assets of a list of endpoints of the same type
    # Ins -> EPtype -> [Endpoint] -> Map Provider (Map AssetName ShippedAssets)
    generateShippedAssets = 
        ins: eptype: eps:
        let generateAssets = config.naps.endpoints.${eptype}.generateAssets;
            allEndpointsAssets = map (ep: generateAssets ep (utils.insEnv ins)) eps;
        in lib.foldl' lib.recursiveUpdate {} allEndpointsAssets;

    # InsName -> Ins -> EpType -> [Endpoits] -> [{states to merges}]
    processEndpointAssets =
        ins: eptype: eps: 
        processShippedAssets 
            (generateShippedAssets ins eptype eps);

    processEndpoints = 
        allendpoints: insname: ins:
        let
            processEndpointType =
                eptype: eps:
                processEndpointAssets ins eptype eps;
        in lib.mkMerge (utils.concatMapAttrsToList processEndpointType allendpoints); 


    processLinks =
        alllinks: insname: ins:
        let
            processLinkType =
                linktype: accesses:
                let hosts = lib.mapAttrsToList (inshost: host: utils.insEnv host) config.naps.internal.links.all.${linktype}.providers;
                    generateAsset = config.naps.links.${linktype}.assets;
                    nativeLinkAssets_ = map (generateAsset (utils.insEnv ins) hosts) accesses;
                    nativeLinkAssets = lib.foldl' lib.recursiveUpdate {} nativeLinkAssets_;

                    allLinkEndpoints = config.naps.links.${linktype}.endpoints;
                in   lib.mkMerge [
                        (processEndpoints allLinkEndpoints insname ins)
                        (lib.mkMerge (processShippedAssets nativeLinkAssets))
                     ];
        in lib.mkMerge (lib.mapAttrsToList processLinkType alllinks);
        
    processService = 
        srvname: {instances, assets, links, endpoints,...}:
        let
            stdAssets = lib.mapAttrsToList (processAssets assets) instances;
            endpointsAssets = lib.mapAttrsToList (processEndpoints endpoints) instances;
            linksAssets = lib.mapAttrsToList (processLinks links) instances;
        in lib.mkMerge (stdAssets ++ endpointsAssets ++ linksAssets);

    generateConfig = 
        envuid: allassets:
        let
            providerConfig = 
                provider: 
                assets:
                let
                    mkConfig = config.naps.assets.${provider}.apply.config;
                in lib.mapAttrsToList (assetname: asset: mkConfig asset) assets;
        in {${envuid} = utils.mergeAll (utils.concatMapAttrsToList providerConfig allassets);};
        
    generateContainersBinds =
        vmname: envassets:
        let
            processContainerAsset =
                envuid: assetname: asset@{installArgs,...}:
                {${vmname}.config.containers.${envuid}.bindMounts.${installArgs.path} = {hostPath = "${utils.paths.secrets}/${envuid}${installArgs.path}"; isReadOnly = true;};};
            processContainerProvider =
                envuid: provider: assets: lib.mkMerge (lib.mapAttrsToList (processContainerAsset envuid) assets);
            processEnv =
                envuid: allassets:
                let env = config.naps.internal.envs.all.${envuid};
                in lib.optionalAttrs (utils.isContainer env) 
                        (utils.mergeAll (lib.mapAttrsToList (processContainerProvider envuid) allassets));
        in utils.mergeAll (lib.mapAttrsToList processEnv envassets);

    

in {
    imports = [
        ./options  
    ];
    naps.internal.assets = lib.mkMerge [
                                (lib.mkMerge (lib.mapAttrsToList processService config.naps.internal.services))
                                {outputs.scripts.generate = generateScript;}
                                {outputs.scripts.install = installScript;}
                                {outputs.config = utils.mergeAll (lib.mapAttrsToList generateConfig config.naps.internal.assets.perEnv);}
                                {outputs.config = utils.mergeAll (lib.mapAttrsToList generateContainersBinds config.naps.internal.assets.perVM);} # bind-mounts of containers secrets
                            ];

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
