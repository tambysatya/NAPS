/* Exposed API to register modules informations */
{flakeRoot, lib,inputs, ...}:
let libtypes = lib.types;
    napstypes = import "${flakeRoot}/lib/types" {inherit lib inputs;};
    types = libtypes // napstypes;
    service = types.submodule {
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
                    type = types.endpoints;
                };
                store = lib.mkOption {
                    description = "Files placed in the store (config files, strings, encrypted password)";
                    type = types.store;
                };
                deployements = lib.mkOption {
                    description = "AttrSet of serviceuid => environment where the service is currently deployed";
                    type = types.attrsOf types.deployementEnvironment;
                    default = {};
                };
                links = lib.mkOption {
                    description = "Dependencies across the other services of the napsstructure";
                    type = types.links;
                };
            };
    };
in
{
   options.naps.services = lib.mkOption {
        description = "Services resources";
        type = lib.types.attrsOf service;
   };

}
