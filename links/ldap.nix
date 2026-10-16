{flakeRoot, lib, inputs, config, pkgs, ...}:

#TODO inprogress

let
    utils = import "${flakeRoot}/lib" {inherit lib inputs;};
    types = lib.types // import "${flakeRoot}/lib/types" {inherit lib inputs;};
    access = types.submodule {
        options = {
            olcRootDN = lib.mkOption {
                description = "DN";
                type = types.str;
            };
            inherit (types) owner reload;
        };
    };

    hostname = "ldap.${config.naps.topology.domain}";

in {
    naps.links.ldap = {
        inherit access;
        endpoints = [
            {type = "tcp"; inherit hostname; port=389;}
            {type = "tcp"; inherit hostname; port=636;} 
        ];
        assets = access:{
            ${utils.ldap_key access} = {
                provider = "ldapssha";
                generateArgs = access;
                installArgs = {inherit (access) owner;};
                inherit (access) reload;
            };
        };
        accessuid = utils.ldap_root;
        waitLinkUp = ""; #TODO
    };
}
