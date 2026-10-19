
/* Exposed endpoints of the service */

{lib,inputs, ...}:
let
    libtypes = lib.types;
    network = import ./network.nix {inherit lib inputs;};
    types = libtypes // network;



in
rec {

    /* Basic endpoint */
    endpoint = types.submodule {
        options = {
            inherit (types) hostname port;
            extraArgs = lib.mkOption {
                description = "Additional parameters, passed to the generator";
                type = types.attrs;
                default = {};
            };
        };
    };

}
