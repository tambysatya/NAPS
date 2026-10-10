{lib, config, ...}:


let types = lib.types;
    allDefaults = lib.filterAttrs (_: {defaultOn, ...}: defaultOn != null) config.naps.services;
in {
options.naps.global.services.defaults = lib.mkOption {
    description = "The description of the services deployed by default";
    type = types.attrsOf types.str;
    default = lib.mapAttrs (_: builtins.getAttr "defaultOn") allDefaults;
};
}
