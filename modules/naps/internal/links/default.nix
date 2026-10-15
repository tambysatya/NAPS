{flakeRoot, lib, inputs, config, path, pkgs,...}:
let
    utils = import "${flakeRoot}/lib" {inherit lib inputs;} // import "${flakeRoot}/providers/lib" {inherit flakeRoot lib inputs path pkgs;};

    
    getHosts = 
        let
            processType = type: _:
                let match = config.naps.links.${type}.service;
                    services = lib.filterAttrs (srvname: _: match == srvname)  config.naps.internal.services; 
                in utils.concatMapAttrsToList (_: {deployements,...}: builtins.attrValues deployements) services;
        in lib.mapAttrs processType config.naps.links;
    
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

    generateProxy = 
        vmname: vmconf:
        let
            processLinkType = 
                linktype: envs: # for each link type, we have a set of environment associated to a set of accesses they request
                let listen = lib.mapAttrsToList
                                (env: _: 
                                 if (utils.isContainer env.type) 
                                 then config.naps.internal.envs.${env}.ip
                                 else "127.0.0.1") envs; # TODO: what to do if the service is hosted locally ?
                    hosts  = map utils.hostIP config.naps.internal.links.hosts.${linktype};
                in {};
        in {};


in {
    imports = [./options];
    naps.internal.links = lib.mkMerge [
        {hosts = getHosts;}
        (lib.mkMerge (utils.concatMapAttrsToList processService config.naps.internal.services))
    ];
}
 
