{flakeRoot, lib, inputs, config,...}:

let
    types = import "${flakeRoot}/lib/types" {inherit lib inputs;};

    links = types.submodule {
        options = {
            requesters = lib.mkOption {
                description = "Recipients of the link: ServiceName -> DeployementEnvironment";
                type = types.attrsOf types.deployementEnvironment;
            };
            providers = lib.mkOption {
                description = "Services providing the link: ServiceName -> ServiceInstance";
                type = types.attrsOf types.serviceInstance;
            };

        };
    };

in {
options.naps.internal.links = lib.mkOption {
    description = "All deployement environments";
    type = types.submodule {
        options = {
            all = lib.mkOption {
                description = "All links. linktype -> {requesters, providers}";
                type = types.attrsOf links;
                default = {};
            };
            perEnv = lib.mkOption {
                description = "All links requested by each environment, by type. Map Env (Map Type (Map UID Access))";
                type = types.attrsOf (types.attrsOf (types.attrsOf types.access));
                default = {};
            };
            perVM = lib.mkOption {
                description = "All links requested by each vm (which includes the links requested by the containers hosted by the vm), grouped by type. VMEnv -> Type -> EnvUID -> AccessUID -> Access ";
                type = types.attrsOf (types.attrsOf (types.attrsOf (types.attrsOf types.access)));
                default = {};
            };
            outputs = lib.mkOption {
                description = "Extra-configuration to be merged with the configuration of each environment: Map EnvUID Config";
                type = types.attrsOf types.config;
                default = {};
            };
        };
    };
};
}
