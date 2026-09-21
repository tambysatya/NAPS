{
description = "Automatic generation of Terraform and NixOS configurations for a small research lab";
	inputs = {
		nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
        naps = {
            url = "github:tambysatya/naps";
            inputs.nixpkgs.follows = "nixpkgs";
        };
	};

  outputs = inputs@{nixpkgs, self, naps,
                    ...}:
    let system ="x86_64-linux";
        lib = nixpkgs.lib;
        pkgs = nixpkgs.legacyPackages.${system};

        modules = [
            # add here extra modules that are not already implemented by NAPS
        ];
        args = {
            extraArgs = {path = ./.;};
            modules = modules ++ [./inventory.nix];
        };
    in  naps.lib.exposeApps args // {
        hydraJobs = {
            inherit (self) checks;
        };
        nixosConfigurations = naps.lib.compileNixos args // {iso = naps.lib.compileIso args;}; 
        terranix = naps.lib.compileTerranix args;

        checks.${system} = naps.lib.gen-config-checks inputs;
  };
}


