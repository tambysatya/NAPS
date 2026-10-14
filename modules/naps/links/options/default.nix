{flakeRoot, lib, inputs, config, ...}:

let
    utils = import ../lib {inherit inputs lib flakeRoot;};    
    types = import "${flakeRoot}/lib/types" {inherit lib inputs;};
    

    accessType = lib.types.submodule {
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
    linkProvider = types.submodule {
        options = {
            access = lib.mkOption {
                description = "The type of the access. Is a submodule containing at least the field reload";
                type = accessType;
                default = null;
            };
            assets = lib.mkOption {
                description = "A function that produces the set of assets consumed by the link: Access -> Map Asset";
                type = types.functionTo (types.attrsOf types.asset);
                default = _: {};
            };
            match = lib.mkOption {
                description = "A function that returns true if a service provides the link: ServiceName -> Bool";
                type = types.functionTo types.bool;
            };
            waitLinkUp = lib.mkOption {
                description = "A script that should wait until the link is up";
                type = types.str;
            };

        };
    };


    #TODO LDAP links
in {

options.naps.links = lib.mkOption {
    description = "Links providers";
    type = types.attrsOf linkProvider;
    default = {};

};

}
