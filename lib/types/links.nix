{lib, inputs, ...}:
let
    libtypes = lib.types;
    filestypes = import ./files.nix {inherit lib inputs;};
    assets = import ./assets.nix {inherit lib inputs;};
    types = libtypes // filestypes // assets;

in
with types;
rec {


    access = lib.types.submodule {
        options = {
            reload = lib.mkOption {
                description = "List of services depending on this link";
                type = types.listOf types.str;
                default = [];
                apply = x: if x == [] then throw "No service depend on this link." else x;
            };
        };
        freeformType = types.attrsOf types.raw;
    };


}
