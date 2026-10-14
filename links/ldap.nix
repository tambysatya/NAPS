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

in {
    naps.links.ldap = {
        inherit access;
        assets = access:{
            ${utils.ldap_key access} = {
                provider = "ldapssha";
                generateArgs = access;
                installArgs = {inherit (access) owner;};
                inherit (access) reload;
            };
        };
        match = srvuid: srvuid == "openldap";
        waitLinkUp = ""; #TODO
    };
}
