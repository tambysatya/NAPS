{flakeRoot, lib, inputs, pkgs, config,...}:

let

    utils = import "${flakeRoot}/lib" {inherit lib inputs;};


    processVM =
        vmname: {ip, services, containers, ...}:
        let
            mkEnv = name: {type="container"; host={container=name; vm=vmname;};};
            ctconfs = lib.imap 
                        (i: name: {
                            ${utils.envUID (mkEnv name)} = {
                                ip = "192.168.100.${lib.toString (50+i)}";
                                env = mkEnv name;
                            };
                        })
                        containers;
            vmconf = {
                        ${vmname} = {
                            env = {type="vm"; host=vmname;};
                            inherit ip;
                        };
                     };
        in utils.mergeAll ([vmconf]  ++ ctconfs);


    processService =  #generates the endpoints list
        _: {endpoints, deployements,...}:
        let processEndpoint = 
            {hostname, port,...}:{
                ${hostname} = map (env: {inherit env port;}) (builtins.attrValues deployements);
            };
        in utils.mergeAll [
                (utils.mergeAll (map processEndpoint endpoints.tcp))
                (utils.mergeAll (map processEndpoint endpoints.http))
                (utils.mergeAll (map processEndpoint endpoints.udp))
            ];


in {
    imports = [./options
               ./users.nix
               ./store.nix
               ./links.nix 
               ./storage.nix
               ./endpoints.nix
               ];
    infra.deploy.systems = utils.mergeAll (lib.mapAttrsToList processVM config.infra.topology.vms);
    infra.deploy.endpoints = utils.mergeAll (lib.mapAttrsToList processService config.infra.services);
}
