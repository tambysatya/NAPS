{flakeRoot, lib, inputs, config, path, pkgs,...}:
let
    utils = import "${flakeRoot}/lib" {inherit lib inputs;};

    processService = 
        srvname: {deployements, endpoints,...}:
        let 
           processEndpointType = 
            env: type: endpoints:
                {
                    ${type} = lib.mkMerge (map ({hostname, port, ...}: {"${hostname}:${lib.toString port}" = [env];} ) endpoints);
                };
           processDeployement =
            envname: env:
            {
                perEnv.${utils.envUID env} = endpoints;
                perVM.${utils.envHost env}.${utils.envUID env} = endpoints;
                hosts = lib.mkMerge (lib.mapAttrsToList (processEndpointType env) endpoints);
            };
        in lib.mkMerge (lib.mapAttrsToList processDeployement deployements);



in {
    imports = [./options];
    naps.internal.endpoints = 
        lib.mkMerge (lib.mapAttrsToList processService config.naps.internal.services);

}
