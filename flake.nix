{
	description = "Automatic generation of Terraform and NixOS configurations for a small research lab";
	inputs = {
		nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
		disko = {
			url = "github:nix-community/disko";
			inputs.nixpkgs.follows = "nixpkgs";
		};
		sops-nix = {
			url = "github:Mic92/sops-nix";
			inputs.nixpkgs.follows = "nixpkgs";
		};
	#	secret-provisioner = {
	#		url = "github:tambysatya/secrets-provisioner";
	#		inputs.nixpkgs.follows = "nixpkgs";
	#	};
    terranix = {
      url = "github:terranix/terranix";
			inputs.nixpkgs.follows = "nixpkgs";
    };
	};

  outputs = inputs@{nixpkgs, self, terranix, ...}:

let
    system = "x86_64-linux";
    lib = nixpkgs.lib;
    utils = import ./lib {inherit lib inputs;};
    pkgs = nixpkgs.legacyPackages.${system};

    flakeRoot = ./.;

    terranix-generator_fun = args:
        let conf = compileModule args;
        in (import ./lib/terranix {inherit lib inputs; inherit (conf) infra registry; }).generator;

    compileModule = # A SINGLE FUNCTION TO RULE THEM ALL
        {inventory, extraArgs ? {path = "${inputs.self.outPath}/.secrets";}}:
           (lib.evalModules {
               specialArgs = {inherit inputs lib pkgs flakeRoot;} // extraArgs;
               modules = [
                  "${nixpkgs}/nixos/modules/misc/assertions.nix"
                  ./modules/infra
                  inventory
                ];
           });
    compileConfig = args: (compileModule args).config;

    compileAssertions = args: (compileModule args).assertions;
    compileInfra = args: (compileConfig args).infra;
    compileRegistry = args: (compileConfig args).registry;

    nixos-generator = args@{inventory, extraArgs}: 
        let infra = compileInfra args; 
            vmconfs = lib.filterAttrs 
                            (name: value: infra.deploy.systems.${name}.env.type == "vm")
                            infra.outputs.systems;
            configs = lib.mapAttrs
                            (vmname: vmconf:
                                lib.nixosSystem {
                                    inherit system; 
                                    specialArgs = {
                                        inherit inputs flakeRoot vmname;
                                        inherit (infra) topology;
                                        deploy = infra.deploy.systems.${vmname};
                                        services = infra.services;
                                    } // extraArgs;
                                    modules = [
                                        inputs.disko.nixosModules.disko    

                                        ./modules/firewall
                                        vmconf
                                    ];
                                })
                            vmconfs;
        in configs;


        compileGenSecrets = 
            args:
                let infra = compileInfra args;
                    script =(import tools/secrets-generator/main.nix 
                                {inherit inputs lib pkgs infra flakeRoot; inherit (args.extraArgs) path;}).generator;
                in {
                    packages.${system}.gen-secrets = script;
                    apps.${system}.gen-secrets = {
                        type = "app";
                        program = lib.getExe script;
                        meta.description = "Generates all the secrets";
                    };
                };

        compileInstallSecrets = 
            args:
            let infra = compileInfra args;
                build = 
                    name: secrets: 
                    let script =(import tools/secrets-generator/main.nix 
                                {inherit inputs lib pkgs infra flakeRoot; inherit (args.extraArgs) path;}).mkInstaller secrets;
                    in {
                        packages.${system}."install-secrets-${name}" = script;
                        apps.${system}."install-secrets-${name}" = {
                            type = "app";
                            program = lib.getExe script;
                            meta.description = "Install secrets for ${name}";
                        };
                    };
            in utils.mergeAll (lib.mapAttrsToList build infra.secrets.perVM);
               


        compileVisualization = 
            args:
                let conf = compileConfig args;
                    script =(import tools/visualization/main.nix 
                                {inherit inputs lib pkgs;
                                 inherit (conf) infra registry;}).main;
                in {
                    packages.${system}.visualization = script;
                    apps.${system}.visualization = {
                        meta.description = "Visualize your infrastructure using graphviz";
                        type = "app";
                        program = lib.getExe script;
                    };
                };
 
                            

    

        
        compileTerranix = 
            args:
                let conf = compileConfig args;
                in terranix.lib.terranixConfiguration {
                            inherit system;
                            modules = [
                               conf.infra.outputs.domains
                            ];
                            extraArgs = {inherit inputs lib;};
                        };
        compileNixos =
            args: nixos-generator args;
        /*
        compileIso = 
            args:
                let
                    infra = compileInfra args;
                in
                lib.nixosSystem {
                    inherit system;
                    specialArgs = {inherit inputs lib; inherit (infra) deploy;} // args.extraArgs;
                    modules = [
                        "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
                        ./profiles/iso.nix
                    ];
                };
         */       
         compileIso = args:
            let infra = compileInfra args;
            in lib.nixosSystem {
                inherit system;
                specialArgs = {inherit inputs lib flakeRoot;} // args.extraArgs;
                modules = [
                        "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
                        ./modules/autoinstall
                        infra.outputs.iso
                ];
            };
         gen-config-checks =
            flake-inputs:
                    builtins.mapAttrs
                        (_: nixosConfig:
                            nixosConfig.config.system.build.toplevel)
                        flake-inputs.self.nixosConfigurations;
                

            

        
        #args = {file=./examples/example.nix; flake-path=inputs.self.outPath;};
        args = {inventory = ./examples/example.nix; extraArgs = {path=flakeRoot;};};


        exposeApps = 
            args:
            utils.mergeAll [
                (compileGenSecrets args) 
                (compileInstallSecrets args)
                (compileVisualization args)
            ];


    in utils.mergeAll [
        (exposeApps args)
        {
          

          lib = {
            inherit compileInfra compileRegistry compileTerranix exposeApps compileNixos compileIso;
            inherit gen-config-checks;
          };


          infra = compileInfra args;
          #registry = compileRegistry args;
          #infra = gen-infra args;
          #registry = gen-registry args;
          terranix = compileTerranix args;
          #nixosConfigurations = compileNixos args // {iso = compileIso args;};

          checks.${system} = gen-config-checks inputs;

          packages.${system}.options-doc = 
            let module = compileModule args;
            in (pkgs.nixosOptionsDoc {options = module.options;}).optionsJSON;
                       

          nixosConfigurations = utils.mergeAll [
                                    (nixos-generator args)
                                    ({iso = compileIso args;})
                                ];

          hydraJobs = {
            inherit (self) checks terranix packages;
          };
          #terranixConfigurations = terranix.lib.terranixConfiguration (terranix-generator ./example.nix);

    #        terranix.lib.terranixConfiguration {inherit system; 
    #                                            modules = [{config = (terranix-generator infra-config.infra);}];};
    #
      }

      ];

}

