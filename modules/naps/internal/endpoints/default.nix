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
    
    mkEndpointsHosts = insname: eps: map (ep: {${utils.epToString ep}.${insname} = config.naps.internal.envs.instances.${insname};}) eps;

    # Generic function to generate the attributes sets
    # hostField = hosts or consumers
    # exposesOrReaches = exposes or reaches (obviously)
    generateAttrSet = 
        hostField: exposesOrReaches: insname: env: eptype: eps: 
        let attrs = mkEndpointsAttrs eptype eps;
        in {
            perEnv.${utils.envUID env}.${eptype}.${exposesOrReaches} = lib.mkMerge attrs;
            perVM = {
                details.${utils.envHost env}.${utils.envUID env}.${eptype}.${exposesOrReaches} = lib.mkMerge attrs;
                global.${utils.envHost env}.${eptype}.${exposesOrReaches} = lib.mkMerge attrs;
            };
            ${hostField}.${eptype} = lib.mkMerge (mkEndpointsHosts insname eps);
        };
    generateAttrSetFromLink =
        hostField: exposesOrReaches: insname: env: linktype: 
        let fun = generateAttrSet hostField exposesOrReaches insname env;
        in lib.mkMerge (lib.mapAttrsToList fun (getLinkEP linktype));
    


    processProvides =
        insname: env: provides:
        let
            processProvide = 
                linktype: generateAttrSetFromLink "hosts" "exposes" insname env linktype;
        in lib.mkMerge (map processProvide provides);

    processEndpoints =
        insname: env: endpoints:
        let
            fun = generateAttrSet "hosts" "exposes" insname env;
        in lib.mkMerge (lib.mapAttrsToList fun endpoints);

    processLinks  =
        insname: env: links:
        let
            fun = generateAttrSetFromLink "consumers" "reaches" insname env;
        in lib.mkMerge (lib.mapAttrsToList (linktype: _: fun linktype) links);
    processService = 
        srvname: {deployements, provides, endpoints, links,...}:
        let
            processDeployement =
                insname: env:
                lib.mkMerge [
                    (processProvides insname env provides)
                    (processEndpoints insname env endpoints)
                    (processLinks insname env links)
                ];
        in lib.mkMerge (lib.mapAttrsToList processDeployement deployements);

    generateProxy = 
        vmname: globalEPS:
        let
            
        in
        {};

in {
    imports = [./options];
    naps.internal.endpoints = lib.mkMerge [
            (lib.mkMerge (lib.mapAttrsToList processService config.naps.internal.services))
        ];

}
