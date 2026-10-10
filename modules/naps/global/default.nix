{lib, config, ...}:


let types = lib.types;
    allDefaults = builtins.attrNames (lib.filterAttrs (_: {default, ...}: default) config.naps.services);
in {
options.naps.global.services.defaults = lib.mkOption {
    description = "The list of services deployed by default";
    type = types.listOf types.str;
    default = allDefaults;
};
}
