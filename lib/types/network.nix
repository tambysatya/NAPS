{lib,inputs,...}:

let
    libtypes = lib.types;
    types = libtypes;
    
in rec {

    ip = lib.mkOption {
        description = "Ip address";
        type = types.str;
    };
    hostname = lib.mkOption {
        description = "Host domain";
        type = types.str;
        example = "auth.local.fr";
    };
    port = lib.mkOption {
        description = "Port on which the service can be reached.";
        type = types.port;
    };

}
