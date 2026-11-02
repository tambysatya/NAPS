{flakeRoot, lib, inputs,...}:

let
    types = import "${flakeRoot}/lib/types" {inherit lib inputs;};
in {
options.naps.internal.envs = lib.mkOption {
    description = "All deployement environments";
    type = types.submodule {
        options = {
            instances = lib.mkOption {
                description = "All service declarations, with the priority and the tags";
                type = types.attrsOf types.serviceInstance;
                default = {};
            };
            all = lib.mkOption {
                description = "All environments. Useful to get the environment from an uid";
                type = types.attrsOf types.deployementEnvironment;
                default = {};
            };
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
            outputs = lib.mkOption {
                description = "Generated container-specific configuration: Map EnvUID Conf";
                type = types.attrsOf types.config;
                default = {};
            };
        };
    };
};
}
