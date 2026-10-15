{flakeRoot, lib, inputs, config, ...}:

let
    utils = import ../lib {inherit inputs lib flakeRoot;};    
    types = import "${flakeRoot}/lib/types" {inherit lib inputs;};
    

    linkProvider = types.submodule {
        options = {
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
                description = "A function that produces the set of assets consumed by the link: Access -> Map Asset";
                type = types.functionTo (types.attrsOf types.asset);
                default = _: {};
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
