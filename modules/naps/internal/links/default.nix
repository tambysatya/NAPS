{flakeRoot, lib, inputs, config, path, pkgs,...}:
let
    utils = import "${flakeRoot}/lib" {inherit lib inputs;} // import "${flakeRoot}/providers/lib" {inherit flakeRoot lib inputs path pkgs;};

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

    generateProxy =
        srvname: {deployements, links, ...}:
        let
            bindAddrs =
                linktype: 
                lib.mapAttrsToList 
                    (_: env: 
                        { 
                            ${utils.envHost env}.${linktype} = {
                                bind = if utils.isContainer env then [(utils.envIP env)] else ["127.0.0.1"]; # TODO; hanlde the case where the service is hosted here
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
 
