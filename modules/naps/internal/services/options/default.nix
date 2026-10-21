/* Exposed API to register modules informations */
{flakeRoot, lib,inputs, config, ...}:
let libtypes = lib.types;
    utils = import "${flakeRoot}/lib" {inherit lib inputs;};
    napstypes = import "${flakeRoot}/lib/types" {inherit lib inputs;};
    types = libtypes // napstypes;


    check = 
        srvname: srvconf@{endpoints, provides, configureListen,...}:
        assert (endpoints == {} || configureListen != null) || throw "Service ${srvname} declares endpoints but configureListen is null";
        assert (provides == [] || configureListen != null) || throw "Service ${srvname} provides a link but configureListen is null";
        srvconf;


in
{
   options.naps.internal.services = lib.mkOption {
        description = "Services resources";
        type = lib.types.attrsOf (types.internalServiceOptions config);
        apply = lib.mapAttrs check;
   };

}
