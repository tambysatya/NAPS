/* Exposed API to register modules informations */
{flakeRoot, lib,inputs, ...}:
let libtypes = lib.types;
    utils = import "${flakeRoot}/lib" {inherit lib inputs;};
    napstypes = import "${flakeRoot}/lib/types" {inherit lib inputs;};
    types = libtypes // napstypes;
in
{
   options.naps.services = lib.mkOption {
        description = "Services resources";
        type = lib.types.attrsOf types.serviceOptions;
   };

}
