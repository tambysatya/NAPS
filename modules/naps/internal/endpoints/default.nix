{flakeRoot, lib, inputs, config, path, pkgs,...}:
let
    utils = import "${flakeRoot}/lib" {inherit lib inputs;} // import "${flakeRoot}/providers/lib" {inherit flakeRoot lib inputs path pkgs;};

    processService = 
        srvname: {deployements, endpoints,...}:
        let 
           processDeployement =
            envname: env:
            {
                perEnv.${utils.envUID env} = endpoints;
                perVM.${utils.envHost env}.${utils.envUID env} = endpoints;
            };
        in lib.mkMerge (lib.mapAttrsToList processDeployement deployements);



in {
    imports = [./options];
    naps.internal.endpoints = 
        lib.mkMerge (lib.mapAttrsToList processService config.naps.internal.services);

}
