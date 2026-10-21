{flakeRoot, lib, inputs, config, ...}:

let
    utils = import "${flakeRoot}/lib" {inherit lib inputs;};
    types = import "${flakeRoot}/lib/types" {inherit lib inputs;};

    /* Given an environment, which endpoints are provided/reached */
    endpoints = types.submodule {
        options = {
            exposes = lib.mkOption {
                description = "Set of exposed endpoints. hostname:port -> Endpoint";
                type = types.attrsOf types.endpoint;
                default = {};
            };
            reaches = lib.mkOption {
                description = "Set of reached endpoints. hostname:port -> Endpoint";
                type = types.attrsOf types.endpoint;
                default = {};
            };
        };
    };

    /* Given an endpoint, which services provides/reaches it*/
    endpointsInfos = types.submodule {
        options = {
            exposedBy = lib.mkOption {
                description = "Which services expose this endpoint";
                type = types.attrsOf types.serviceInstance;
                default = {};
            };
            reachedBy = lib.mkOption {
                description = "Which services reache this endpoint";
                type = types.attrsOf types.serviceInstance;
                default = {};
            };
        };
    };
    vmEndpointsInfos = types.submodule {
        options = {
            endpoint = lib.mkOption {
                description = "Endpoint";
                type = types.endpoint;
            };
            locally = lib.mkOption {
                description = "Local instances exposing/reaching the endpoint (i.e. native or contained instances running on the VM)";
                type = endpointsInfos;
                default = {};
            };
            globally = lib.mkOption {
                description = "Other endpoints information exposing/reaching the endpoint (that are neither native or running within a container on the VM)";
                type = endpointsInfos;
                default = {};
            };
        };
    };

in {
    options.naps.internal.endpoints.global.hosts = lib.mkOption {
        description = "Endpoints hosts: EndpointType -> hostname:port -> ServiceID -> ServiceInstance";
        type = types.attrsOf (types.attrsOf (types.attrsOf types.serviceInstance));
        default = {};
    };
    options.naps.internal.endpoints.global.consumers = lib.mkOption {
        description = "Which services consume each endpoint: EndpointType -> hostname:port -> ServiceID -> ServiceInstance";
        type = types.attrsOf (types.attrsOf (types.attrsOf types.serviceInstance));
        default = {};
    };
    options.naps.internal.endpoints.perEnv = lib.mkOption {
        description = "Endpoints of each environment: Env -> EndpointType -> {exposes, reaches}";
        type = types.attrsOf (types.attrsOf endpoints);
        default = {};

    };
    options.naps.internal.endpoints.perVM = lib.mkOption { 
        description = "Endpoints of each VM, partitionned between local instances and global instances: VM -> EndpointType -> EndpointName -> {locally, globally} -> {exposedBy, reachedBy}";
        type = types.attrsOf (types.attrsOf (types.attrsOf vmEndpointsInfos));
        default = {};
        /* The field locally/globally are completed here, by partitioning the hosts and the consumers sets*/
        apply = vms:
            lib.mapAttrs 
                        (vmname: alleps:
                            lib.mapAttrs
                                (eptype: eps:
                                    lib.mapAttrs
                                        (epname: ep@{locally, globally, endpoint,...}: #only the endpoint field is filled
                                            let
                                                global = config.naps.internal.endpoints.global;
                                                reachedBy = global.consumers.${eptype}.${epname} or {}; # remember that some services are not consumed by NAPS (TODO  declare them explicitely or forbid them?)
                                                exposedBy = global.hosts.${eptype}.${epname} or {};
                                                reachedByPart = utils.partitionAttrs (_: ins: utils.envHost (utils.serviceEnv ins) == vmname) reachedBy;
                                                exposedByPart = utils.partitionAttrs (_: ins: utils.envHost (utils.serviceEnv ins) == vmname) exposedBy;
                                            in
                                                ep // 
                                                {
                                                    locally = {
                                                        reachedBy = reachedByPart.right;
                                                        exposedBy = exposedByPart.right;

                                                    };
                                                    globally = {
                                                        reachedBy = reachedByPart.wrong;
                                                        exposedBy = exposedByPart.wrong;
                                                    };
                                               })
                                        eps)
                                alleps) 
                        vms;
    };
    /*
    options.naps.internal.endpoints.perVM.details = lib.mkOption { #TODO add a distinction between NATIVE and CONTAINERS ?
        description = "Endpoints of each VM: VM -> Env -> EndpointType -> Endpoints";
        type = types.attrsOf (types.attrsOf (types.attrsOf endpoints));
        default = {};
    };
    options.naps.internal.endpoints.perVM.global = lib.mkOption {
        description = "Endpoints of each VM, where all the environments are aggregated. VM -> EndpointType -> Endpoints";
        type = types.attrsOf (types.attrsOf endpoints);
        default = {};
    };
    options.naps.internal.endpoints.perVM.proxy = lib.mkOption {
        description = "Proxy configuration of each VM";
        type = types.attrsOf types.haproxyConfig;
        default = {};
    };
    options.naps.internal.endpoints.outputs.proxy = lib.mkOption {
        description = "Proxy final configuration file of each VM";
        type = types.attrsOf types.str;
        readOnly = true;
        default = lib.mapAttrs (vmname: proxy: lib.concatStringsSep "\n" proxy.config) config.naps.internal.endpoints.perVM.proxy;
    };
    options.naps.internal.endpoints.outputs.firewall = lib.mkOption {
        description = "Firewall final configuration of each VM";
        type = types.attrs;
        readOnly = true;
        default = lib.mapAttrs (vmname: proxy: proxy.firewall) config.naps.internal.endpoints.perVM.proxy;
    };
    */
}

