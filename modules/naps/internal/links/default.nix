{flakeRoot, lib, inputs, config, path, pkgs,...}:
let
    utils = import "${flakeRoot}/lib" {inherit lib inputs;} // import "${flakeRoot}/providers/lib" {inherit flakeRoot lib inputs path pkgs;};

    
    /*
    getHosts = 
        let
            processType = type: _:
                let srvname = config.naps.links.${type}.service;
                    srvconf = config.naps.internal.services.${srvname}; 
                    allendpoints = utils.concatMapAttrsToList (type: eps: map (val: val // {type=val;}) eps) srvconf.endpoints;
                    link = lib.filter ({link,...}: link == type) allendpoints;
                in utils.concatMapAttrsToList (_: {deployements,...}: builtins.attrValues deployements) services;
        in lib.mapAttrs processType config.naps.links;
    */
    getHosts = 
        let
            processSrv =
                srvname: srvconf@{deployements, endpoints,...}: 
                utils.concatMapAttrsToList 
                    (eptype: eps:
                        map
                            ({link, hostname, port,...}:
                             lib.optionalAttrs (link != null){
                               ${link} = lib.mapAttrsToList (_: env: {inherit env; endpoint = {type=eptype; inherit hostname port;};}) deployements;
                             }
                            ) 
                            eps)
                    endpoints;
        in utils.concatMapAttrsToList processSrv config.naps.internal.services;
    
    processService = 
        srvname: {deployements, links, ...}:
        let processEnv = 
                insuid: env: utils.concatMapAttrsToList (processLinkType insuid env) links;
            processLinkType =
                insuid: env: linktype: links: map (processLink insuid env linktype) links;
            processLink =
                insuid: env: linktype: link: 
                let
                    accessuid = config.naps.links.${linktype}.accessuid link;
                in {
                    perEnv.${utils.envUID env}.${linktype}.${accessuid} = link;
                    perVM.${utils.envHost env}.${linktype}.${utils.envUID env}.${accessuid} = link;

                };
        in utils.concatMapAttrsToList processEnv deployements;

    /*
    generateProxy = 
        vmname: vmconf:
        let
            processLinkType = 
                linktype: envs: # for each link type, we have a set of environment associated to a set of accesses they request
                let 
                    getEnv = envname: config.naps.internal.env.all.${envname};
                    allEnvs = map getEnv (builtins.attrNames envs);
                    listen = map 
                                (env:
                                 if (utils.isContainer env) 
                                 then config.naps.internal.envs.${env}.ip
                                 else "127.0.0.1") allEnvs; 
                    endpoints = map (builtins.getAttr "env") config.naps.internal.links.hosts.${linktype};
                    srvname = config.naps.links.${linktype}.service;
                    srvconf = config.naps.internal.services.${srvname};
                    isLocal = builtins.elem vmname (map (env: utils.envHost env) (builtins.attrValues srvconf.deployements));
                in {
                        ${vmname} =  [{
                            listen = if isLocal then ["0.0.0.0"] else listen;
                            endpoints = endpoints;
                        }];

                };

        in lib.mapAttrsToList processLinkType vmconf;
    */
    generateProxy =
        srvname: {deployements, links, ...}:
        let
            bindAddrs =
                linktype: 
                lib.mapAttrsToList 
                    (_: env: 
                        { 
                            ${utils.envHost env}.${linktype} = {
                                bind = if utils.isContainer env then [(utils.envIP env)] else ["127.0.0.1"];
                                backends = config.naps.internal.links.hosts.${linktype};
                            };
                        }
                    )
                    deployements;
            processLink =
                linktype: _:
                lib.mkMerge [
                    (lib.mkMerge (bindAddrs linktype))
                ];
                
        in lib.mkMerge (lib.mapAttrsToList processLink links);

in {
    imports = [./options];
    naps.internal.links = lib.mkMerge [
        {hosts = lib.mkMerge getHosts;}
        (lib.mkMerge (utils.concatMapAttrsToList processService config.naps.internal.services))
        {proxy = lib.mkMerge (lib.mapAttrsToList generateProxy config.naps.internal.services);}
    ];
}
 
