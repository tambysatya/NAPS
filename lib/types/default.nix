{lib, inputs,...}:

let
    libtypes = lib.types;
    serviceType = types.str;

    deployement = import ./deployement.nix {inherit lib inputs;};
    files = import ./files.nix {inherit lib inputs;};
    links = import ./links.nix {inherit lib inputs; };
    networktypes = import ./network.nix {inherit lib inputs;};
    endpointstypes = import ./endpoints.nix {inherit lib inputs;};
    proxy = import ./proxy.nix {inherit lib inputs;};
    users = import ./users.nix {inherit lib inputs;};
    volumes = import ./volumes.nix {inherit lib inputs;};
    assets = import ./assets.nix {inherit lib inputs;};
    services = import ./services.nix {inherit lib inputs;};
    config = import ./config.nix {inherit lib inputs;};

    types = libtypes // files // deployement // links // networktypes // endpointstypes // proxy // users // volumes // assets // services // config;



in
types
