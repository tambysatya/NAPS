{inputs, lib, config, naps, registry, pkgs, vmname,...}:

let
    utils = import "${inputs.self.outPath}/lib/utils.nix" {inherit lib;};
    comp = import "${inputs.self.outPath}/lib/compiler" {inherit inputs lib pkgs naps registry vmname;};

    allUsers = 
        utils.mergeAll (lib.mapAttrsToList (_:sconf: sconf.users) registry.services);
in {
    imports = [
               ./options.nix
               ./nixos/base.nix
               ./nixos/native.nix
               ./nixos/nixos-container.nix
              ];    
}
