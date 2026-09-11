/* Exposed API to register modules informations */
{flakeRoot, lib,inputs, ...}:
let libtypes = lib.types;
    infratypes = import "${flakeRoot}/lib/types" {inherit lib inputs;};
    types = libtypes // infratypes;
    service = types.submodule {
            options = {
                users = lib.mkOption {
                    description = "List of service users";
                    type = types.listOf types.user;
                };
                persistent = lib.mkOption {
                    description = "Persistent directories, managed by the service. The infrastructure must explicitely declare a persistent storage for each of them";
                    type = types.listOf types.volume;
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
                    description = "Dependencies across the other services of the infrastructure";
                    type = types.links;
                };
            };
    };
in
{
   options.infra.services = lib.mkOption {
        description = "Services resources";
        type = lib.types.attrsOf service;
   };

}
