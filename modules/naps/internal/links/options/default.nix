{flakeRoot, lib, inputs, config,...}:

let
    types = import "${flakeRoot}/lib/types" {inherit lib inputs;};

    hostsLink = types.submodule {
        options = {
            endpoint = lib.mkOption {
                description = "Endpoint to reach the link";
                type = types.endpoint;
            };
            envs = lib.mkOption {
                description = "Deployement environment of the host of the link";
                type = types.listOf types.deployementEnvironment;
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
                type = types.listOf hostsLink;
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
                description = "All hosts providing each links (e.g. postgres, s3,...). Type -> EndpointType -> HostsLink = (Endpoint, [Env])";
                type = types.attrsOf (types.attrsOf hostsLink);
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
