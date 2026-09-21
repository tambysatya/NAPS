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
        in (import ./lib/terranix {inherit lib inputs; inherit (conf) naps registry; }).generator;

    services = [
        ./services/forgejo/register.nix
        ./services/garage/register.nix
        ./services/hydra/register.nix
        ./services/journald-remote/register.nix
        ./services/keycloak/register.nix
        ./services/nextcloud/register.nix
        ./services/openldap/register.nix
        ./services/postgres/register.nix
        ./services/step-ca/register.nix
    ];
    compileModule = # A SINGLE FUNCTION TO RULE THEM ALL
        {
         extraArgs ? {
            path = "${inputs.self.outPath}/.secrets";
         },
         modules # extra modules that are imported (typically: services). Must includes two files: register.nix and default.nix
        }:
           (lib.evalModules {
               specialArgs = {inherit inputs lib pkgs flakeRoot;} // extraArgs;
               modules = [
                  "${nixpkgs}/nixos/modules/misc/assertions.nix"
                  ./modules/naps
                ] ++ modules ++ services;
           });
    compileConfig = args: (compileModule args).config;

    compileAssertions = args: (compileModule args).assertions;
    compileNAPS = args: (compileConfig args).naps;
    compileRegistry = args: (compileConfig args).registry;

    nixos-generator = args@{extraArgs, ...}: 
        let naps = compileNAPS args; 
            vmconfs = lib.filterAttrs 
                            (name: value: naps.deploy.systems.${name}.env.type == "vm")
                            naps.outputs.systems;
            configs = lib.mapAttrs
                            (vmname: vmconf:
                                lib.nixosSystem {
                                    inherit system; 
                                    specialArgs = {
                                        inherit inputs flakeRoot vmname;
                                        inherit (naps) topology;
                                        deploy = naps.deploy.systems.${vmname};
                                        services = naps.services;
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
                let naps = compileNAPS args;
                    script =(import tools/secrets-generator/main.nix 
                                {inherit inputs lib pkgs naps flakeRoot; inherit (args.extraArgs) path;}).generator;
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
            let naps = compileNAPS args;
                build = 
                    name: secrets: 
                    let script =(import tools/secrets-generator/main.nix 
                                {inherit inputs lib pkgs naps flakeRoot; inherit (args.extraArgs) path;}).mkInstaller secrets;
                    in {
                        packages.${system}."install-secrets-${name}" = script;
                        apps.${system}."install-secrets-${name}" = {
                            type = "app";
                            program = lib.getExe script;
                            meta.description = "Install secrets for ${name}";
                        };
                    };
            in utils.mergeAll (lib.mapAttrsToList build naps.secrets.perVM);
               


        compileVisualization = 
            args:
                let conf = compileConfig args;
                    script =(import tools/visualization/main.nix 
                                {inherit inputs lib pkgs;
                                 inherit (conf) naps registry;}).main;
                in {
                    packages.${system}.visualization = script;
                    apps.${system}.visualization = {
                        meta.description = "Visualize your napsstructure using graphviz";
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
                               conf.naps.outputs.domains
                            ];
                            extraArgs = {inherit inputs lib;};
                        };
        compileNixos =
            args: nixos-generator args;

         compileIso = args:
            let naps = compileNAPS args;
            in lib.nixosSystem {
                inherit system;
                specialArgs = {inherit inputs lib flakeRoot naps;} // args.extraArgs;
                modules = [
                        "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
                        ./modules/autoinstall
                        naps.outputs.iso
                ];
            };
         gen-config-checks =
            flake-inputs:
                    builtins.mapAttrs
                        (_: nixosConfig:
                            nixosConfig.config.system.build.toplevel)
                        flake-inputs.self.nixosConfigurations;
                

            

        
        #args = {file=./examples/example.nix; flake-path=inputs.self.outPath;};
        args = {modules = [./examples/example.nix]; extraArgs = {path=flakeRoot;};};


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
            inherit compileModule compileNAPS compileTerranix exposeApps compileNixos compileIso;
            inherit gen-config-checks;
            inherit utils;
          };


          naps = compileNAPS args;
          #registry = compileRegistry args;
          #naps = gen-naps args;
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
          nixosModules = {
            naps.services = ./modules/naps/services;
          };
          hydraJobs = {
            inherit (self) checks terranix packages;
          };
          templates = {
            default = {
                path = ./templates;
                description = "Scheme of configurations.";
            };
          };
          #terranixConfigurations = terranix.lib.terranixConfiguration (terranix-generator ./example.nix);

    #        terranix.lib.terranixConfiguration {inherit system; 
    #                                            modules = [{config = (terranix-generator naps-config.naps);}];};
    #
      }

      ];

}

