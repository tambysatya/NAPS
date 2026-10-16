{flakeRoot, lib, inputs,...}:

let
    types = import "${flakeRoot}/lib/types" {inherit lib inputs;};

    hostLink = types.submodule {
        options = {
            env = lib.mkOption {
                description = "Deployement environment of the host of the link";
                type = types.deployementEnvironment;
            };
            endpoint = lib.mkOption {
                description = "Endpoint to reach the link";
                type = types.linkEndpoint;
            };
        };
    };
    proxy = types.submodule {
        options = {
            bind = lib.mkOption {
                description = "List of IP address to listen";
                type = types.listOf types.str;
                default = [];
                apply = ips: if ips == [] then throw "No listening ip for this proxy" else lib.unique ips; 
            };
            backends = lib.mkOption {
                description = "List of Backends";
                type = types.listOf hostLink;
                default = [];
                apply = eps: if eps == [] then throw "No backends for this link" else lib.unique eps;
            };
        };
    };

in {
options.naps.internal.links = lib.mkOption {
    description = "All deployement environments";
    type = types.submodule {
        options = {
            hosts = lib.mkOption {
                description = "All hosts providing each links (e.g. postgres, s3,...). Map Type [HostLink]";
                type = types.attrsOf (types.listOf hostLink);
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
                description = "Proxy configuration of each VM:  VMName -> LinkType -> Proxy = ([Bind], [Backends])";
                type = types.attrsOf (types.attrsOf proxy);
                default = {};
            };
        };
    };
};
}
