{flakeRoot, lib, inputs, config, path, pkgs,...}:
let
    utils = import "${flakeRoot}/lib" {inherit lib inputs;};


    processExposes = 
        insname: ins: protocol: epname: endpoint@{hostname, port, ...}: {
            all.${protocol}.${epname} = endpoint;
            providers.${protocol}.${epname} = {inherit endpoint; hosts.${insname} = ins;};
            perVM.${utils.insHostUID ins}.${protocol}.exposes.${epname} = {inherit endpoint; hosts.${insname} = ins;};
        };
    processReaches = 
        insname: ins: protocol: epname: endpoint@{hostname, port, ...}: {
            all.${protocol}.${epname} = endpoint;
            consumers.${protocol}.${epname} = {inherit endpoint; hosts.${insname} = ins;};
            perVM.${utils.insHostUID ins}.${protocol}.consumes.${epname} = {inherit endpoint; hosts.${insname} = ins;};
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
        
    /*
    processEndpoint = 
        hostsOrReaches: insname: ins:
        proto: ep@{hostname, port,...}:
        let
            envuid = utils.insEnvUID ins;
            epname = utils.epToString ep;
            globalField = if hostsOrReaches == "hosts" then "hosts" else "consumers";
            proxyField = if hostsOrReaches == "hosts" then "reverse" else "forward";
            proxyValue = 
                if proxyField == "forward"
                then {${envuid}.${epname} = ep;}
                else {${epname}.${insname} = ins;};
            perEnvField = if hostsOrReaches == "hosts" then "exposes" else "reaches";
        in {
            all.${proto}.${epname} = ep;
            perEnv.${envuid}.${perEnvField}.${proto}.${epname} = ep;
            global.${globalField}.${proto}.${epname}.${insname} = ins;
            ir.${utils.insHostUID ins}.${proto}.${proxyField} = proxyValue;
        };
    processEndpointType = 
        hostsOrReaches: insname: ins: proto: endpoints: 
        lib.mkMerge 
            (map 
                (processEndpoint hostsOrReaches insname ins proto) 
                (map (checkEndpoint proto) endpoints)); #we validate here the type of the endpoint
    processProvidesField =
        insname: ins: provides:
        let
            process = 
                linktype:
                let 
                    endpoints = config.naps.links.${linktype}.endpoints; # Map EndpointType [Endpoints]
                in lib.mkMerge (lib.mapAttrsToList (processEndpointType "hosts" insname ins) endpoints);
        in lib.mkMerge (map process provides);

    processEndpointsField =
        insname: ins: endpoints:
        let
            process = proto: eps: processEndpointType "hosts" insname ins proto eps;
        in lib.mkMerge 
            (lib.mapAttrsToList process endpoints);

    processLinksField =
        insname: ins: links:
        let
            process =
                linktype: accesses:
                let
                    endpoints = config.naps.links.${linktype}.endpoints;
                in lib.mkMerge (lib.mapAttrsToList (processEndpointType "reaches" insname ins) endpoints);
        in lib.mkMerge (lib.mapAttrsToList process links);

    processService = 
        srvname: {instances , provides, endpoints, links,...}:
        let
            processInstance =
                insname: ins:
                lib.mkMerge [
                    (processProvidesField insname ins provides)
                    (processEndpointsField insname ins endpoints)
                    (processLinksField insname ins links)
                ];
        in lib.mkMerge (lib.mapAttrsToList processInstance instances);

        */
        /*
    generateProxy =
        vmname: alleps:
        let
            vmenv = config.naps.envs.all.${vmname};
            process =
                proto: ir:
                let fun = config.naps.lib.endpoints.${proto}.reverseProxy;
                in fun vmenv ir;
        in utils.concatMapAttrsStringsSep "\n" process alleps; 
    generateFirewall  =
        vmname: alleps:
        let
            vmenv = config.naps.envs.all.${vmname};
            process =
                proto: ir:
                let fun = config.naps.lib.endpoints.${proto}.reverseFirewall;
                in fun vmenv ir;
        in utils.mergeAll (lib.mapAttrsToList process alleps); 

    protocolAssets = 
        env: proto: eps:
        let
            genAssets = config.naps.lib.endpoints.${proto}.generateAssets;
            assets = lib.mapAttrsToList (epname: ep: genAssets ep env) eps;
        in lib.mkMerge assets;

     generateAssets = 
        envname: alleps:
        let
            env = config.naps.envs.all.${envname};
        in lib.mkMerge (lib.mapAttrsToList (protocolAssets env) alleps);
    */
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
