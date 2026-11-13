{flakeRoot, lib, inputs, config,...}:

let
    types = import "${flakeRoot}/lib/types" {inherit lib inputs;};

    consumer = types.submodule {
        options = {
            instance = lib.mkOption {
                description = "Service Instance description of the consumer";
                type = types.serviceInstance;
            };
            accesses = lib.mkOption {
                description = "Access requested by the consumers (e.g. buckets if the link is S3). Map AccessUID Access";
                type = types.attrsOf types.access;
                default = {};
            };
        };
    };
    linkIR = types.submodule {
        options = {
            endpoints = lib.mkOption {
                description = "Endpoints exposed by this link resource: Map Protocol (Map EndpointName Endpoint)";
                type = types.attrsOf (types.attrsOf types.endpoint);
                default = {};
            };
            providers = lib.mkOption {
                description = "Service Instances providing this link resource: Map ServiceUID ServiceInstance";
                type = types.attrsOf types.serviceInstance;
                default = {};
            };
            consumers = lib.mkOption {
                description = "Service Instances consuming this link resource: Map ServiceUID ServiceInstance";
                type = types.attrsOf consumer;
                default = {};
            };
        };
    };


in {
options.naps.links = lib.mkOption {
    description = "All deployement environments";
    type = types.submodule {
      options = {
            all = lib.mkOption {
                description = ''
                    Links intermediate representation. For each link type, provides:
                        - the endpoints exposed by the links
                        - the set of instances providing the links
                        - the set of instances consuming the links = (instance description, set of accesses)
                    Map LinkName LinkIR
                    LinkIR = {
                        endpoints : Map Protocol (Map EndpointName Endpoint)
                        provides : Map InstanceUID Instance
                        consumers : {instance: ServiceInstance, accesses = Map AccessUID Access}
                    }
                '';
                type = types.attrsOf linkIR;
                default = {};
            };
            /*
            perEnv = lib.mkOption {
                description = "All links requested by each environment, by type. Map Env (Map Type (Map UID Access))";
                type = types.attrsOf (types.attrsOf (types.attrsOf types.access));
                default = {};
            };
            perVM = lib.mkOption {
                description = "All links requested by each vm (which includes the links requested by the containers hosted by the vm), grouped by type. VMEnv -> Type -> EnvUID -> AccessUID -> Access ";
                type = types.attrsOf (types.attrsOf (types.attrsOf (types.attrsOf types.access)));
                default = {};
            };
            */
            outputs = lib.mkOption {
                description = "Extra-configuration to be merged with the configuration of each environment: Map EnvUID Config";
                type = types.attrsOf types.config;
                default = {};
            };
        };
    };
};
}
