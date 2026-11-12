{flakeRoot, lib, inputs, config, path, pkgs,...}:
let
    utils = import "${flakeRoot}/lib" {inherit lib inputs;};

    getLinkEP = linktype: config.naps.links.${linktype}.endpoints;

    checkEndpoint = proto: ep@{extraArgs,...}:
       let applyMerge =
                type: value: 
                if type == null then value else type.merge [] [{inherit value; file = "module.naps.internal.endpoints.default.nix";}];
           check = config.naps.endpoints.${proto}.extraArgsType;
       in ep // {extraArgs = applyMerge check extraArgs;};

    # Transforms a list of endpoints into a set of hostname:port => endpoint.
    # Performs type checking of the extraArgs as well
    # [Endpoints] -> attrset hostname:port endpoint
    mkEndpointsAttrs = proto: eps: map (ep: {${utils.epToString ep} = checkEndpoint proto ep;}) eps;
    
    # ServiceInstance -> [Endpoints] -> {EndpointName = {ServiceInstance}}
    mkEndpointsHosts = insname: eps: map (ep: {${utils.epToString ep}.${insname} = config.naps.internal.envs.instances.${insname};}) eps;

    processEP = 
        insname: ins: protocol: epname: ep@{hostname, port, ...}:
        {
            all.${protocol}.${epname} = ep;
            hosts.${protocol}.${epname}.${insname} = ins;
            perEnv.${utils.insEnvUID ins}.${protocol}.${epname} = ep;
            perVM.${utils.insHostUID ins}.${protocol}.${epname}.${insname} = ins;
        };

    processProtocol = 
        insname: ins: protocol: eps:
        lib.mkMerge (lib.mapAttrsToList (processEP insname ins protocol) eps);
    processInput = 
        insname: allendpoints:
        let ins = config.naps.envs.instances.${insname};
        in  lib.mkMerge (lib.mapAttrsToList (processProtocol insname ins) allendpoints);
        
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

in {
    imports = [
        ./options
    ];
    naps.endpoints = lib.mkMerge [
        (lib.mkMerge (lib.mapAttrsToList processInput config.naps.inputs.endpoints))
        {outputs.proxy= lib.mapAttrs generateProxy config.naps.endpoints.perVM;}
        {outputs.firewall= utils.mergeAll (lib.mapAttrsToList generateFirewall config.naps.endpoints.perVM);}
    ];
    naps.inputs.assets = lib.mkMerge (lib.mapAttrsToList generateAssets config.naps.endpoints.perEnv);
    /*
    naps.internal.endpoints = lib.mkMerge [
            (lib.mkMerge (lib.mapAttrsToList processService config.naps.internal.services))
            {outputs.proxy= lib.mapAttrs generateProxy config.naps.internal.endpoints.ir;}
            {outputs.firewall= utils.mergeAll (lib.mapAttrsToList generateFirewall config.naps.internal.endpoints.ir);}
        ];
    */

}
