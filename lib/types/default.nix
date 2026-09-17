{lib, inputs,...}:

let
    libtypes = lib.types;
    serviceType = types.str;

    deployement = import ./deployement.nix {inherit lib inputs;};
    files = import ./files.nix {inherit lib inputs;};
    secrets = import ./secrets.nix {inherit lib inputs;};
    links = import ./links.nix {inherit lib inputs; };
    networktypes = import ./network.nix {inherit lib inputs;};
    endpointstypes = import ./endpoints.nix {inherit lib inputs;};
    store = import ./store.nix {inherit lib inputs;};
    users = import ./users.nix {inherit lib inputs;};
    volumes = import ./volumes.nix {inherit lib inputs;};

    types = libtypes // files // deployement // secrets // links // networktypes // endpointstypes // store // users // volumes;



in
types
