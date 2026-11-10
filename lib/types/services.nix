
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


    link = config: lib.mkOption {
        description = "List of links provided by this service";
        type = types.listOf types.str;
        default = [];
        apply = ls: if ls != [] && ! builtins.all (l: builtins.hasAttr l config.naps.links) ls then throw "${ls} contains invalid links" else lib.unique ls;
    };



    serviceOptions = config: {...}: {
            options = {
                provides = link config;

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
                    type = types.attrsOf types.resource;
                    default = {};
                };
                endpoints = lib.mkOption {
                    description = "Various endpoints exposed by the service";
                    type = types.attrsOf (types.listOf types.endpoint);
                    apply = eps: 
                        let check = 
                                eptype: ep:
                                assert (builtins.hasAttr eptype config.naps.endpoints) || throw "Unknown endpoint ${eptype}";
                                ep;

                        in lib.mapAttrs check eps;
                };
                assets = lib.mkOption {
                    description = ''
                        Files placed in the store (config files, strings, encrypted password), grouped by providers.
                        Should be of the form <filename/dirname> = {...}
                        Map Provider (Map AssetName Asset)
                        Note that the installation path is defaulted to <secretPath>/<assetName>
                    '';
                    type = types.attrsOf (types.attrsOf types.asset);
                    default = {};
                    apply =
                        lib.mapAttrs 
                            (assetType: assets:
                                lib.mapAttrs 
                                    (assetname: asset@{installArgs ? {}, ...}:  #sets the default value of path
                                        let installArgs' = if builtins.hasAttr "path" installArgs && installArgs.path != null && installArgs.path != ""
                                                           then installArgs
                                                           else installArgs // {path = "${utils.paths.secrets}/${assetname}";};
                                        in asset // {installArgs = installArgs';})
                                     assets);

                };
                links = lib.mkOption {
                    description = "Dependencies across the other services of the napsstructure: Map Type  [Access]";
                    type = types.attrsOf (types.listOf types.access) ;
                    default = {};
                };
                configureListen = lib.mkOption {
                    description = "A function to sets the listening IP(s) address(es). Mandatory if endpoints are provided. Note that the prefix config. should NOT be specified. Address -> AttrSet";
                    type = types.nullOr (types.functionTo types.attrs);
                    default = null;
                    example = "addr: {services.darkhttpd.address = addr;}";
                };
                instances = lib.mkOption {
                    description = "Map InstanceName ServiceInstance";
                    internal = true;
                    type = types.attrsOf types.serviceInstance;
                    default = {};
                };

            };
    };

    /*
    # a simple decoration of serviceOptions
    internalServiceOptions = config: {...}: {
        imports = [(serviceOptions config)]; #TODO good practice ? Or config is implicit ?
        options = {
            instances = lib.mkOption {
                description = "Map InstanceName ServiceInstance";
                internal = true;
                type = types.attrsOf types.serviceInstance;
                default = {};
            };
        };
    };
*/
in {
    serviceOptions = config: types.submodule (serviceOptions config);
    #internalServiceOptions = config: types.submodule (internalServiceOptions config);
}
