{flakeRoot, lib, inputs, config,...}:

let
    infratypes= import "${flakeRoot}/lib/types" {inherit inputs lib;};
    types = infratypes;

    serviceModules = map (name: "${flakeRoot}/services/${name}/register.nix") types.serviceNames;

in {
  imports = [./topology # Inventory of the deployement (which service on which vm on which host)
             ./services # Requirements of each available service
             ./links    # Summary of the links per vm
             ./secrets # Summary of the secrets (for the secrets-generator)
             ./volumes # Summary of the storage allocation (for the migration procedure)
             ./deploy # Summary of the requirements (per vm and per container)
             ./outputs] ++ serviceModules;

/*  
  config.assertions = lib.mapAttrsToList
    (vmName: vm: {
      assertion = builtins.hasAttr vm.host config.infra.hosts;
      message = "Undefined ${vm.host} for ${vmName}";
    }) config.infra.vms;
*/
}
