{lib, inputs, ...}:

let 
    envtypes= import ./deployement.nix {inherit lib inputs;}; 
    nettypes= import ./network.nix {inherit lib inputs;}; 
    types = lib.types // envtypes // nettypes;
in

rec {

    /* Basic types constructors */
    filename = lib.mkOption {
        description = "Name of the file";
        type = types.str;
    };

    owner = lib.mkOption {
        description = "Username of the owner";
        type = types.str;
        default = "root";
    };
    group = lib.mkOption {
        description = "Group. If set to null, it will be assigned to a group having the same name as the user";
        type = types.nullOr types.str;
        default = null;
    };
    reload = lib.mkOption {
        description = "Services to be reloaded";
        type = types.listOf types.str;
        default = [];
    };
    dirmode = lib.mkOption {
        description = "Permissions of the directory";
        type = types.str;
        default = "0700";
    };
    filemode = lib.mkOption {
        description = "Permissions of the file";
        type = types.str;
        default = "0400";
    };






}
