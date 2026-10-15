{flakeRoot, lib, inputs,...}:

let
    types = import "${flakeRoot}/lib/types" {inherit lib inputs;};
    proxy = types.submodule {
        options = {
            inherit (types) endpoint;
            endpoints = lib.mkOption {
                description = "List of Backend IPs";
                type = types.listOf types.str;
                default = [];
                apply = ips: if ips == [] then throw "No backends for this link" else ips;
            };
            listen = lib.mkOption {
                description = "List of interface to listen";
                type = types.listOf types.str;
                default = [];
                apply = ips: if ips == [] then throw "No listening ip for this proxy" else lib.uniq ips; 
            };
        };
    };
in {
options.naps.internal.links = lib.mkOption {
    description = "All deployement environments";
    type = types.submodule {
        options = {
            hosts = lib.mkOption {
                description = "All hosts providing each links (e.g. postgres, s3,...). Map Type [Env]";
                type = types.attrsOf (types.listOf types.deployementEnvironment);
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
            proxy = lib.mkOption {
                description = "Proxy configuration of each VM.";
                type = types.attrsOf proxy;
                default = {};
            };
        };
    };
};
}
