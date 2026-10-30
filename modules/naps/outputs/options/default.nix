{flakeRoot, lib, inputs, pkgs, config,...}:
let
    types = import "${flakeRoot}/lib/types" {inherit inputs lib;};

    utils = import "${flakeRoot}/lib" {inherit inputs lib;};


    /* We need to manually reimplement some options, otherwise the conflict resolution won't allow
       us to define naps.outputs.<name>.config from multiple different places */

/*
    config = types.submodule {
        options ={
            config.imports = lib.mkOption {
                internal = true;
                description = "List of imports";
                type = types.listOf (types.either types.str types.path);
                default = [];
            };
            config.sops = lib.mkOption {
                internal = true;
                description = "Sops configuration";
                type = types.attrs;
                default = {};
            };
            config.services.step-renew = lib.mkOption {
                internal = true;
                description = "Step Renew configuration";
                type = types.attrs;
                default = {};
            };
            config.fileSystems = lib.mkOption {
                internal = true;
                type = types.attrs;
                default = {};
            };
            config.systemd.mounts = lib.mkOption {
                internal = true;
                type = types.listOf types.attrs;
                default = [];
            };
            config.systemd.services= lib.mkOption {
                internal = true;
                type = types.attrs;
                default = {};
            };
            config.networking = lib.mkOption {
                internal = true;
                type = types.attrs;
                default = {};
            };



        };
    };
*/

    
in
{
    options.naps.outputs.systems = lib.mkOption {
            description = "System configurations";
            type = types.attrsOf types.config;
            default = {};
    };
    options.naps.outputs.domains= lib.mkOption {
        description = "Generated Terranix configurations";
        #type = types.attrsOf config;
        type = types.extraConfigType;
        default = {};
    };
    options.naps.outputs.iso= lib.mkOption {
        description = "Bootstrap ISO config";
        #type = types.attrsOf config;
        type = types.extraConfigType;
        default = {};
    };
}
