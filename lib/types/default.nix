{lib, inputs,...}:

let
    libtypes = lib.types;
    serviceType = types.str;

    deployement = import ./deployement.nix {inherit lib inputs;};
    files = import ./files.nix {inherit lib inputs;};
    links = import ./links.nix {inherit lib inputs; };
    networktypes = import ./network.nix {inherit lib inputs;};
    endpointstypes = import ./endpoints.nix {inherit lib inputs;};
    users = import ./users.nix {inherit lib inputs;};
    volumes = import ./volumes.nix {inherit lib inputs;};
    assets = import ./assets.nix {inherit lib inputs;};

    types = libtypes // files // deployement // links // networktypes // endpointstypes // users // volumes // assets;



in
types
