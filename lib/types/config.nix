{lib, inputs,...}:
let

    types = lib.types;
    utils = import ../default.nix {inherit lib inputs;};
in rec {

    extraConfigType = lib.types.mkOptionType {
        name = "extraConfig";
        description = "An attrset merged recursively with utils.mergeAll";
        check = lib.isAttrs;
        merge = loc: defs:
          utils.mergeAll (map (def: def.value) defs);
    };

    config = types.submodule {
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
}
