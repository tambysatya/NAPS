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

    processEndpoint = 
        hostsOrReaches: insname: ins:
        eptype: ep@{hostname, port,...}:
        let
            envuid = utils.envUID (utils.insEnv ins);
            epname = utils.epToString ep;
            globalField = if hostsOrReaches == "hosts" then "hosts" else "consumers";
            proxyField = if hostsOrReaches == "hosts" then "reverse" else "forward";
            proxyValue = 
                if proxyField == "forward"
                then {${envuid}.${epname} = ep;}
                else {${epname}.${insname} = ins;};
        in {
            global.${globalField}.${eptype}.${epname}.${insname} = ins;
            proxy.${utils.envHost (utils.insEnv ins)}.${eptype}.${proxyField} = proxyValue;
        };
    processEndpointType = 
        hostsOrReaches: insname: env: eptype: endpoints: 
        let
            ins = config.naps.internal.envs.instances.${insname};
        in lib.mkMerge 
            (map 
                (processEndpoint hostsOrReaches insname ins eptype) 
                (map (checkEndpoint eptype) endpoints)); #we validate here the type of the endpoint
    processProvidesField =
        insname: env: provides:
        let
            process = 
                linktype:
                let 
                    endpoints = config.naps.links.${linktype}.endpoints; # Map EndpointType [Endpoints]
                in lib.mkMerge (lib.mapAttrsToList (processEndpointType "hosts" insname env) endpoints);
        in lib.mkMerge (map process provides);

    processEndpointsField =
        insname: env: endpoints:
        let
            process = eptype: eps: processEndpointType "hosts" insname env eptype eps;
        in lib.mkMerge 
            (lib.mapAttrsToList process endpoints);

    processLinksField =
        insname: env: links:
        let
            process =
                linktype: accesses:
                let
                    endpoints = config.naps.links.${linktype}.endpoints;
                in lib.mkMerge (lib.mapAttrsToList (processEndpointType "reaches" insname env) endpoints);
        in lib.mkMerge (lib.mapAttrsToList process links);

    processService = 
        srvname: {deployements, provides, endpoints, links,...}:
        let
            processDeployement =
                insname: env:
                lib.mkMerge [
                    (processProvidesField insname env provides)
                    (processEndpointsField insname env endpoints)
                    (processLinksField insname env links)
                ];
        in lib.mkMerge (lib.mapAttrsToList processDeployement deployements);

in {
    imports = [./options];
    naps.internal.endpoints = lib.mkMerge [
            (lib.mkMerge (lib.mapAttrsToList processService config.naps.internal.services))
            #{proxy = lib.mkMerge (lib.mapAttrsToList generateProxy config.naps.internal.endpoints.perVM);}
        ];

}
