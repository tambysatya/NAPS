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
                    in genFun acc assetname generateArgs ++ [(utils.give assetname recipients)];
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
        mv .secrets/out/${config.naps.topology.provisioner.hostname}/* .secrets/provisioner/ssl/
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
            processVM = 
                vmname: assetskinds:
                let scriptsPerProviders = lib.mapAttrsToList processProvider assetskinds; 
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
            perVM = lib.mkMerge (map (uid: {${utils.envHostUID config.naps.internal.envs.all.${uid}}.${provider}.${assetname} = asset'';})  recipientsUID);
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

    generateConfig = 
        envuid: allassets:
        let
            providerConfig = 
                provider: 
                assets:
                let
                    mkConfig = config.naps.assets.${provider}.apply.config;
                in lib.mapAttrsToList (assetname: asset: mkConfig asset) assets;
        in {${envuid} = lib.mkMerge (utils.concatMapAttrsToList providerConfig allassets);};
        
    generateContainersBinds =
        envuid: allassets:
        let
            env = config.naps.internal.envs.all.${envuid};
            processContainerAsset =
                assetname: asset@{installArgs,...}:
                {${utils.envHostUID env}.config.containers.bindMounts.${installArgs.path} = [{hostPath = installArgs.path; isReadOnly = true;}];};
            processContainerProvider =
                provider: assets: lib.mapAttrsToList processContainerAsset assets;
        in lib.mkMerge (utils.concatMapAttrsToList processContainerProvider allassets);

    

in {
    imports = [
        ./options  
    ];
    naps.internal.assets = lib.mkMerge [
                                (lib.mkMerge (lib.mapAttrsToList processService config.naps.internal.services))
                                {outputs.scripts.generate = generateScript;}
                                {outputs.scripts.install = installScript;}
                                {outputs.config = lib.mkMerge (lib.mapAttrsToList generateConfig config.naps.internal.assets.perEnv);}
                                {outputs.config = lib.mkMerge (lib.mapAttrsToList generateContainersBinds config.naps.internal.assets.perEnv);} # bind-mounts of containers secrets
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
