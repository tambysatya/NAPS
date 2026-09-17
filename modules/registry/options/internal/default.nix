{lib, inputs, ...}:

let
    types = lib.types;
    crypto = import ./crypto.nix {inherit lib inputs;};
in {
    internal = types.submodule {
        options = {
            crypto = lib.mkOption {
                description = "Secrets dispatch over the napsstructure";
                type = crypto.crypto;
            };
        };
    };
}
