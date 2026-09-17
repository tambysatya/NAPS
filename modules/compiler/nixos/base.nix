/* Compilations steps that are performed on all backends (containers or native) */


{lib, config, inputs, pkgs, naps, registry, vmname, vmconf, ...}:
let 
    utils = import "${inputs.self.outPath}/lib/utils.nix" {inherit lib;}; 
    vars = import "${inputs.self.outPath}/lib/vars.nix" {inherit lib naps registry inputs;};
    comp = import "${inputs.self.outPath}/lib/compiler" {inherit lib inputs pkgs registry naps vmname;};

    generateUsers = 
        vmconf@{services, containers, ...}:
            let allUsers = 
                    utils.mergeAll
                        (map (name: registry.services."${name}".users) (services ++ containers));
            in {
               users = lib.mapAttrs (name: id: {uid=lib.mkForce id; group=name; isSystemUser=true;}) allUsers;
               groups = lib.mapAttrs (name: id: {gid=lib.mkForce id;}) allUsers;
            };
in {
    config.users = generateUsers vmconf;
}


