
{lib, inputs,...}:

let
    utils = import ../default.nix {inherit lib inputs;};
    users = import ./users.nix {inherit lib inputs;};
    filestypes= import ./files.nix {inherit lib inputs;}; 
    deployement = import ./deployement.nix {inherit lib inputs;};
    nettypes= import ./network.nix {inherit lib inputs;}; 
    endpointstypes = import ./endpoints.nix {inherit lib inputs;};
    links = import ./links.nix {inherit lib inputs; };
    volumes = import ./volumes.nix {inherit lib inputs;};
    assets = import ./assets.nix {inherit lib inputs;};
    types = lib.types // filestypes // nettypes // endpointstypes // volumes // assets // links // deployement // users;

    serviceOptions = config: {...}: {
            options = {
                path = lib.mkOption {
                    description = "Path to the configuration file";
                    type = types.path;
                    example = "./default.nix";
                };
                users = lib.mkOption {
                    description = "Attrset of service users";
                    type = types.attrsOf types.user;
                    default ={};
                };
                persistent = lib.mkOption {
                    description = "Persistent directories, managed by the service. The napsstructure must explicitely declare a persistent storage for each of them";
                    type = types.listOf types.volume;
                    default = [];
                };
                endpoints = lib.mkOption {
                    description = "Various endpoints exposed by the service";
                    type = types.endpoints config;
                };
                assets = lib.mkOption {
                    description = "Files placed in the store (config files, strings, encrypted password). Should be of the form <filename/dirname> = {...}";
                    type = types.attrsOf types.asset;
                    default = {};
                    apply =
                        lib.mapAttrs 
                            (assetname: asset@{installArgs ? {}, ...}:  #sets the default value of path
                                let installArgs' = if builtins.hasAttr "path" installArgs 
                                                   then installArgs
                                                   else installArgs // {path = "${utils.paths.secrets}/${assetname}";};
                                in asset // {installArgs = installArgs';});

                };
                links = lib.mkOption {
                    description = "Dependencies across the other services of the napsstructure: Map Type  [Access]";
                    type = types.attrsOf (types.listOf types.access) ;
                    default = {};
                };
                defaultOn = lib.mkOption {
                    description = "If set, this service is deployed by default everywhere, but can be disabled explicitely in each vm configuration";
                    type = types.nullOr (types.enum ["containers" "vms" "all"]);
                    default = null;
                };
            };
    };

    # a simple decoration of serviceOptions
    internalServiceOptions = config: {...}: {
        imports = [(serviceOptions config)]; #TODO good practice ? Or config is implicit ?
        options = {
            deployements = lib.mkOption {
                description = "AttrSet of serviceuid => environment where the service is currently deployed";
                type = types.attrsOf types.deployementEnvironment;
                default = {};
            };
        };
    };

in {
    serviceOptions = config: types.submodule (serviceOptions config);
    internalServiceOptions = config: types.submodule (internalServiceOptions config);
}
