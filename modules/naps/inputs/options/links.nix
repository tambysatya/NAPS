{flakeRoot, lib, inputs, config,...}:

let
    types = import "${flakeRoot}/lib/types" {inherit lib inputs;};
    utils = import "${flakeRoot}/lib" {inherit lib inputs;};

    linksInputs = types.submodule {
        options = {
            provides = lib.mkOption {
                description = "List of links provided by the environment";
                type = types.listOf types.str;
                default = [];
                apply = links: lib.map checkProvides (lib.unique links); #TODO checks if the link exists. Warns if the link is not consumed
            };
            consumes = lib.mkOption {
                description = ''
                    Links consumed by the environment, using unique access identifiers
                    Map LinkName (Map AccessUID Access)
                '';
                type = types.attrsOf (types.attrsOf types.access);
                default = {}; # TODO checks if the links exists AND is provided
                apply = lib.mapAttrs checkConsumes;
            };
        };
    };


    allProvidedLinks = lib.concatLists (lib.mapAttrsToList (_: {provides, consumes}: provides) config.naps.inputs.links); 
    allConsumedLinks = lib.concatLists (lib.mapAttrsToList (_: {provides, consumes}: builtins.attrNames consumes) config.naps.inputs.links); 
    linkExists = link: builtins.hasAttr link config.naps.lib.links;
    linkProvided = link: builtins.elem link allProvidedLinks;
    linkConsumed = link: builtins.elem link allConsumedLinks;

    checkAccess =
        link: accessuid: access:
        utils.checkType "modules/naps/inputs/options/links.nix" config.naps.lib.${link}.access access;
    checkAccesses = 
        link: conf: # conf: Map AccessUID Access
        lib.mapAttrs (checkAccess link) conf;

    # Weird name: but checks the consumes FIELD
    checkConsumes = link: conf:
        assert (linkExists link) || throw "Unknown link ${link}. Please define it in naps.lib.links";
        assert (linkProvided link) || throw "No service provides ${link}. Refusing to evaluate";
        checkAccesses conf;

    checkProvides = link:
        assert (linkExists link) || throw "Unknown link ${link}. Please define it in naps.lib.links";
        assert (linkConsumed link) || builtins.trace "Warning: link ${link} is provided but not consumed." true;
        link;

in {
    options.naps.inputs.links = lib.mkOption {
        description = "Instances providing a link. Map ServiceUID LinkInputs";
        type = types.attrsOf linksInputs;
        default = {};
    };
}


