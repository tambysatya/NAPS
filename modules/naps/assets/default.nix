{flakeRoot, lib, inputs, config, path, pkgs,...}:
let

    utils = import "${flakeRoot}/lib" {inherit lib inputs;} // import "${flakeRoot}/modules/naps/assets/providers/lib" {inherit lib inputs path pkgs flakeRoot;};
   
            
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
                    let recipients = config.naps.assets.ir.recipients.${providername}.${assetname};
                    in genFun acc assetname generateArgs ++ [(utils.give config assetname recipients)];
            processProvider =
                acc: providername: assets:
                let provider = config.naps.assets.providers.${providername};
                    genFun = provider.apply.generate;
                in lib.foldlAttrs (generateAsset providername genFun) acc assets;
        in lib.concatStringsSep "\n" (lib.foldlAttrs processProvider [] config.naps.assets.ir.all);
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
            (builtins.attrNames config.naps.envs.vms)}
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
            config.naps.envs.containers}
        
        # Generates the secrets
        ${generateAssets}

        # Generates the provisioner tls certificates
        mkdir -p .secrets/provisioner/{ssl,secrets,mtls}
        rm -Rf .secrets/provisioner/ssl/* #clean the repository
        ${lib.concatStringsSep "\n" 
            (config.naps.assets.providers.tls.apply.generate
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
                let provider = config.naps.assets.providers.${providername};
                    installFun = provider.apply.install;
                in lib.concatStringsSep "\n"
                        (lib.mapAttrsToList installFun assets);
            
            processEnv =
                envuid: assetskinds: 
                let scriptsPerProviders = lib.mapAttrsToList processProvider assetskinds; 
                    env = config.naps.envs.all.${envuid};
                    installPrefix = 
                        if utils.isContainer env 
                        then ''"$PREFIX"${utils.paths.secrets}/${envuid}''
                        else ''"$PREFIX"'';
                in ''
                    install -d -m 0711 -o root -g root "$PREFIX"${utils.paths.secrets}${lib.optionalString (utils.isContainer env) "/${envuid}"}
                    ${if (utils.isContainer env) 
                        then
                        ''
                            IS_CONTAINER=Y
                            CT_NAME="${utils.envUID env}"
                            TMP_PREFIX="$PREFIX" 
                            TMP_SRCPREFIX="$SRCPREFIX" 
                            PREFIX="$PREFIX${utils.paths.secrets}/${envuid}"
                            SRCPREFIX="$SRCPREFIX/${envuid}"

                            echo "Installing $CT_NAME secrets:"
                        ''
                       else '' IS_CONTAINER=N ''}
                    ${lib.concatStringsSep "\n" scriptsPerProviders}
                    ${lib.optionalString (utils.isContainer env) 
                        ''
                            PREFIX="$TMP_PREFIX"
                            SRCPREFIX="$TMP_SRCPREFIX"
                        ''}
                '';
            processVM = 
                vmname: envuids: 
                let scriptsPerProviders = lib.mapAttrsToList processEnv envuids; 
                in ''
                    install -d -m 0711 -o root -g root "$PREFIX"${utils.paths.secrets}
                    ${lib.concatStringsSep "\n" scriptsPerProviders}
                '';
        in lib.mapAttrs processVM config.naps.assets.ir.perVM;

    processAsset = 
        provider: 
        recipientsUID: # [EnvUID] : list of recipients
        assetname: asset@{installArgs,...}:
        let 
        in
        {
            all.${provider}.${assetname} = asset;
            recipients.${provider}.${assetname} = recipientsUID;
            perEnv = lib.mkMerge (map (uid: {${uid}.${provider}.${assetname} = asset;})  recipientsUID);
            perVM = lib.mkMerge (map (uid: {${utils.envHostUID config.naps.envs.all.${uid}}.${uid}.${provider}.${assetname} = asset;})  recipientsUID);
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
        lib.mkMerge(
            lib.mapAttrsToList 
                (provider: shippedassets:
                    lib.mkMerge (
                        lib.mapAttrsToList 
                            (assetname: {asset, recipients}:
                                processAsset provider recipients assetname asset)
                            shippedassets))
                allassets);
  
    /*
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

                    #allLinkEndpoints = config.naps.links.${linktype}.endpoints;
                in   #processEndpoints allLinkEndpoints insname ins;
                    lib.mkMerge (processShippedAssets nativeLinkAssets);
        in lib.mkMerge (lib.mapAttrsToList processLinkType alllinks);
        
    processProvides =
        provides: insname: ins:
        let
            processProvide =
                provide:
                let allLinkEndpoints = config.naps.links.${provide}.endpoints;
                in processEndpoints allLinkEndpoints insname ins;
        in lib.mkMerge (map processProvide provides);

    processService = 
        srvname: {instances, provides, assets, links, endpoints,...}:
        let
            stdAssets = lib.mapAttrsToList (processAssets assets) instances;
            endpointsAssets = lib.mapAttrsToList (processEndpoints endpoints) instances;
            linksAssets = lib.mapAttrsToList (processLinks links) instances;
            providesAssets = lib.mapAttrsToList (processProvides provides) instances;
        in lib.mkMerge (stdAssets ++ endpointsAssets ++ linksAssets ++ providesAssets);

    */
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
                envuid: provider: assets:
                lib.optionalAttrs 
                    (provider != "plain") 
                    (lib.mkMerge (lib.mapAttrsToList (processContainerAsset envuid) assets));
            processEnv =
                envuid: allassets:
                let env = config.naps.envs.all.${envuid};
                in lib.optionalAttrs (utils.isContainer env) 
                        (utils.mergeAll (lib.mapAttrsToList (processContainerProvider envuid) allassets));
        in utils.mergeAll (lib.mapAttrsToList processEnv envassets);


in {
    imports = [
        ./options  
        ./providers
    ];
    naps.assets = lib.mkMerge [
        {
            ir = processShippedAssets config.naps.assets.inputs;
            outputs.scripts.generate = generateScript;
            outputs.scripts.install = installScript;
            outputs.config = 
                utils.mergeAll 
                    (lib.mapAttrsToList generateConfig config.naps.assets.ir.perEnv ++ 
                     lib.mapAttrsToList generateContainersBinds config.naps.assets.ir.perVM); # bind-mounts of containers secrets

        }

    ];
    /*
    naps.internal.assets = lib.mkMerge [
                                (lib.mkMerge (lib.mapAttrsToList processService config.naps.internal.services))
                                {outputs.scripts.generate = generateScript;}
                                {outputs.scripts.install = installScript;}
                                {outputs.config = utils.mergeAll (lib.mapAttrsToList generateConfig config.naps.internal.assets.perEnv);}
                                {outputs.config = utils.mergeAll (lib.mapAttrsToList generateContainersBinds config.naps.internal.assets.perVM);} # bind-mounts of containers secrets
                            ];
*/
}
