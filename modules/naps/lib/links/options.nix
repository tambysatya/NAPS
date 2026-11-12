{flakeRoot, lib, inputs, config, ...}:

let
    utils = import ../lib {inherit inputs lib flakeRoot;};    
    types = import "${flakeRoot}/lib/types" {inherit lib inputs;};
    

    linkProvider = types.submodule {
        options = {
            endpoints = lib.mkOption {
                description = "Which endpoints are necessarily exposed by a service providing the link: EndpointType -> [Endpoints]";
                type = types.attrsOf (types.listOf types.endpoint);
                default = {};
                apply = eps: if eps == {} then throw "Link unreachable: some endpoints must be specified" else eps;
            };
            access = lib.mkOption {
                description = "The type of the access. Is a submodule containing at least the field reload";
                type = types.access;
                default = null;
            };
            accessuid = lib.mkOption {
                description = "Construct a unique ID from the access";
                type = types.functionTo types.str;
            };
            assets = lib.mkOption {
                description = ''
                    A function that produces the set of assets consumed by the link, based on the deployement environment
                    and the link providers environments:
                    Env -> [Env] -> Access -> Map Provider (Map AssetName ShippedAsset)
                '';
                type = types.functionTo(types.functionTo (types.functionTo (types.attrsOf (types.attrsOf types.shippedAsset))));
                default = _: _: _: {};
            };
            waitLinkUp = lib.mkOption {
                description = "A script that should wait until the link is up";
                type = types.str;
            };

        };
    };


    #TODO LDAP links
in {

options.naps.lib.links = lib.mkOption {
    description = "Links providers";
    type = types.attrsOf linkProvider;
    default = {};

};

}
