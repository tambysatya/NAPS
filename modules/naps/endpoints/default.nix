{flakeRoot, lib, inputs, config, path, pkgs,...}:
let
    utils = import "${flakeRoot}/lib" {inherit lib inputs;};

    getLinkEP = linktype: config.naps.links.${linktype}.endpoints;

    checkEndpoint = eptype: ep@{extraArgs,...}:
       let applyMerge =
                type: value: 
                if type == null then value else type.merge [] [{inherit value; file = "module.naps.internal.endpoints.default.nix";}];
           check = config.naps.endpoints.${eptype}.extraArgsType;
       in ep // {extraArgs = applyMerge check extraArgs;};

    # Transforms a list of endpoints into a set of hostname:port => endpoint.
    # Performs type checking of the extraArgs as well
    # [Endpoints] -> attrset hostname:port endpoint
    mkEndpointsAttrs = eptype: eps: map (ep: {${utils.epToString ep} = checkEndpoint eptype ep;}) eps;
    
    # ServiceInstance -> [Endpoints] -> {EndpointName = {ServiceInstance}}
    mkEndpointsHosts = insname: eps: map (ep: {${utils.epToString ep}.${insname} = config.naps.internal.envs.instances.${insname};}) eps;

    processEP = 
        insname: ins: protocol: epname: ep@{hostname, port, ...}:
        {
            all.${protocol}.${epname} = ep;
            hosts.${protocol}.${epname}.${insname} = ins;
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
        eptype: ep@{hostname, port,...}:
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
            all.${eptype}.${epname} = ep;
            perEnv.${envuid}.${perEnvField}.${eptype}.${epname} = ep;
            global.${globalField}.${eptype}.${epname}.${insname} = ins;
            ir.${utils.insHostUID ins}.${eptype}.${proxyField} = proxyValue;
        };
    processEndpointType = 
        hostsOrReaches: insname: ins: eptype: endpoints: 
        lib.mkMerge 
            (map 
                (processEndpoint hostsOrReaches insname ins eptype) 
                (map (checkEndpoint eptype) endpoints)); #we validate here the type of the endpoint
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
            process = eptype: eps: processEndpointType "hosts" insname ins eptype eps;
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

    generateProxy =
        vmname: alleps:
        let
            vmenv = config.naps.envs.all.${vmname};
            global = config.naps.endpoints.global;
            process =
                eptype: ir:
                let fun = config.naps.lib.endpoints.${eptype}.generateProxy;
                in fun vmenv global.hosts.${eptype} global.consumers.${eptype} ir;
        in utils.concatMapAttrsStringsSep "\n" process alleps; 
    generateFirewall  =
        vmname: alleps:
        let
            vmenv = config.naps.envs.all.${vmname};
            process =
                eptype: ir:
                let fun = config.naps.lib.endpoints.${eptype}.generateFirewall;
                in fun vmenv ir;
        in utils.mergeAll (lib.mapAttrsToList process alleps); 

    generateAssets = 
        */

in {
    imports = [
        ./options
    ];
    naps.endpoints = lib.mkMerge [
        (lib.mkMerge (lib.mapAttrsToList processInput config.naps.inputs.endpoints))
        #{outputs.proxy= lib.mapAttrs generateProxy config.naps.endpoints.ir;}
        #{outputs.firewall= utils.mergeAll (lib.mapAttrsToList generateFirewall config.naps.endpoints.ir);}
    ];
    /*
    naps.internal.endpoints = lib.mkMerge [
            (lib.mkMerge (lib.mapAttrsToList processService config.naps.internal.services))
            {outputs.proxy= lib.mapAttrs generateProxy config.naps.internal.endpoints.ir;}
            {outputs.firewall= utils.mergeAll (lib.mapAttrsToList generateFirewall config.naps.internal.endpoints.ir);}
        ];
    */

}
