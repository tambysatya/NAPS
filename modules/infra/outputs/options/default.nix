{flakeRoot, lib, inputs, pkgs, config,...}:
let
    types = lib.types;

    utils = import "${flakeRoot}/lib" {inherit inputs lib;};


    /* We need to manually reimplement some options, otherwise the conflict resolution won't allow
       us to define infra.outputs.<name>.config from multiple different places */

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
    extraConfigType = lib.types.mkOptionType {
        name = "extraConfig";
        description = "An attrset merged recursively with utils.mergeAll";
        check = lib.isAttrs;
        merge = loc: defs:
          utils.mergeAll (map (def: def.value) defs);
    };

    systemConfig = types.submodule {
        options = {
            config = lib.mkOption {
                description = "Generated NixOS configurations";
                type = extraConfigType;
                default = {};
            };
            imports = lib.mkOption {
                description = "Generated NixOS imports";
                type = types.listOf (types.either types.str types.path);
                default = [];
                apply = lib.unique;
            };
        };

    };
    
in
{
    options.infra.outputs.systems = lib.mkOption {
            description = "System configurations";
            type = types.attrsOf systemConfig;
            default = {};
    };
    options.infra.outputs.domains= lib.mkOption {
        description = "Generated Terranix configurations";
        #type = types.attrsOf config;
        type = extraConfigType;
        default = {};
    };
    options.infra.outputs.iso= lib.mkOption {
        description = "Bootstrap ISO config";
        #type = types.attrsOf config;
        type = extraConfigType;
        default = {};
    };
}
