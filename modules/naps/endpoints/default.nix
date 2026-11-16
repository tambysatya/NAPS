{flakeRoot, lib, inputs, config, path, pkgs,...}:
let
    utils = import "${flakeRoot}/lib" {inherit lib inputs;};


    processExposes = 
        insname: ins: protocol: epname: endpoint@{hostname, port, ...}: {
            all.${protocol}.${epname} = endpoint;
            providers.${protocol}.${epname} = {inherit endpoint; instances.${insname} = ins;};
            perVM.${utils.insHostUID ins}.${protocol}.exposes.${epname} = {inherit endpoint; instances.${insname} = ins;};
        };
    processReaches = 
        insname: ins: protocol: epname: endpoint@{hostname, port, ...}: {
            all.${protocol}.${epname} = endpoint;
            consumers.${protocol}.${epname} = {inherit endpoint; instances.${insname} = ins;};
            perVM.${utils.insHostUID ins}.${protocol}.reaches.${utils.insEnvUID ins} = {
                env = utils.insEnv ins;
                endpoints.${epname} = endpoint;
            };
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
        
in {
    imports = [
        ./options
    ];
    naps.endpoints = lib.mkMerge [
        (lib.mkMerge (lib.mapAttrsToList processInput config.naps.inputs.endpoints))
        #{outputs.proxy= lib.mapAttrs generateProxy config.naps.endpoints.perVM;}
        #{outputs.firewall= utils.mergeAll (lib.mapAttrsToList generateFirewall config.naps.endpoints.perVM);}
    ];
    #naps.inputs.assets = lib.mkMerge (lib.mapAttrsToList generateAssets config.naps.endpoints.perEnv);
    /*
    naps.internal.endpoints = lib.mkMerge [
            (lib.mkMerge (lib.mapAttrsToList processService config.naps.internal.services))
            {outputs.proxy= lib.mapAttrs generateProxy config.naps.internal.endpoints.ir;}
            {outputs.firewall= utils.mergeAll (lib.mapAttrsToList generateFirewall config.naps.internal.endpoints.ir);}
        ];
    */

}
