{flakeRoot, lib, inputs, config,...}:

let
    napstypes= import "${flakeRoot}/lib/types" {inherit inputs lib;};
    types = napstypes;

    serviceModules = map (name: "${flakeRoot}/services/${name}/register.nix") types.serviceNames;

in {
  imports = [./topology # Inventory of the deployement (which service on which vm on which host)
             ./services # Requirements of each available service
             ./global # Global configuration 

             ./endpoints # Endpoints providers
             ./links     # Links providers
             ./assets    # Assets providers


             # Intermediate representations
             ####
             ./internal
            
             ./deploy # Summary of the requirements (per vm and per container) [source of truth: services, assets, volumes]
             ./outputs];

/*  
  config.assertions = lib.mapAttrsToList
    (vmName: vm: {
      assertion = builtins.hasAttr vm.host config.naps.hosts;
      message = "Undefined ${vm.host} for ${vmName}";
    }) config.naps.vms;
*/
}
