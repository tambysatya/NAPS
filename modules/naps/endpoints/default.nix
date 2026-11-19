{flakeRoot, lib, inputs, config, path, pkgs,...}:
let
    utils = import "${flakeRoot}/lib" {inherit lib inputs;};


    processExposes = 
        insname: ins: protocol: epname: endpoint@{hostname, port, ...}: {
            all.${protocol}.${epname} = endpoint;
            providers.${protocol}.${epname} = {inherit endpoint; instances.${insname} = ins;};
            perVM.${utils.insHostUID ins} = {
                ${protocol}.exposes.${epname} = {inherit endpoint; instances.${insname} = ins;};
            };
            perEnv.${utils.insEnvUID ins}.${protocol}.exposes.${epname} = endpoint;
        };
    processReaches = 
        insname: ins: protocol: epname: endpoint@{hostname, port, ...}: {
            all.${protocol}.${epname} = endpoint;
            consumers.${protocol}.${epname} = {inherit endpoint; instances.${insname} = ins;};
            perVM.${utils.insHostUID ins} = {
                ${protocol}.reaches.${utils.insEnvUID ins} = {
                    env = utils.insEnv ins;
                    endpoints.${epname} = endpoint;
                };
            };
            perEnv.${utils.insEnvUID ins}.${protocol}.reaches.${epname} = endpoint;
        };
    processExposesProtocol = 
        insname: ins: protocol: exposes:
        lib.mkMerge (lib.mapAttrsToList (processExposes insname ins protocol) exposes);

    processReachesProtocol = 
        insname: ins: protocol: reaches:
        lib.mkMerge (lib.mapAttrsToList (processReaches insname ins protocol) reaches);
    processInput = 
        insname: {exposes, reaches}:
        let ins = config.naps.envs.instances.${insname};
        in  lib.mkMerge 
                (lib.mapAttrsToList (processExposesProtocol insname ins) exposes ++
                 lib.mapAttrsToList (processReachesProtocol insname ins) reaches);

    generateProxyAndFirewall =
        vmname: vmir:
        let
            vmenv = config.naps.envs.all.${vmname};
            processIR =
                protocol: {exposes, reaches}:
                let
                    inherit (config.naps.lib.endpoints.${protocol}) generateProxy generateFirewall;
                in
                {
                    proxy.${vmname} = generateProxy vmenv config.naps.endpoints.providers.${protocol} reaches exposes;
                    firewall = generateFirewall vmenv reaches exposes;
                };
            in lib.mkMerge (lib.mapAttrsToList processIR vmir);

    generateEtcHosts =
        envname: alleps:
        let
            env = config.naps.envs.all.${envname};            
            proxy = if utils.isContainer env then utils.envPrivateHostIP env else "127.0.0.1";

            processProtocol =
                proto: {reaches, ...}:
                lib.mapAttrsToList (epname: {hostname,...}: hostname) reaches;
        in {
            ${proxy}=lib.mkMerge (lib.mapAttrsToList processProtocol alleps);
        };


    generateAssets = 
        vmname: vmir:
        let
            processEndpoint = 
                genAsset: epname: {endpoint, instances}:
                lib.mkMerge (lib.mapAttrsToList (insname: ins: genAsset endpoint (utils.insEnv ins)) instances);
            processIR =
                protocol: {exposes, reaches}:
                lib.mkMerge 
                    (lib.mapAttrsToList 
                        (processEndpoint config.naps.lib.endpoints.${protocol}.generateAssets) 
                        exposes);

        in lib.mkMerge (lib.mapAttrsToList processIR vmir);
 
        
in {
    imports = [
        ./options
    ];
    naps.endpoints = lib.mkMerge [
        (lib.mkMerge (lib.mapAttrsToList processInput config.naps.inputs.endpoints))
        {outputs= lib.mkMerge (lib.mapAttrsToList generateProxyAndFirewall config.naps.endpoints.perVM);}
        {outputs.hostsFile= lib.mapAttrs generateEtcHosts config.naps.endpoints.perEnv;}
    ];
    naps.inputs.assets = lib.mkMerge (lib.mapAttrsToList generateAssets config.naps.endpoints.perVM);
}
