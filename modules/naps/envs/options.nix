{flakeRoot, lib, inputs,...}:

let
    types = import "${flakeRoot}/lib/types" {inherit lib inputs;};
in {
options.naps.envs = lib.mkOption {
    description = "All deployement environments";
    type = types.submodule {
        options = {
            vms = lib.mkOption {
                description = "Virtual machines";
                type = types.attrsOf types.deployementEnvironment;
                default = {};
            };
            containers = lib.mkOption {
                description = "Nixos-Containers";
                type = types.attrsOf types.deployementEnvironment;
                default = {};
            };
        };
    };
};
}
