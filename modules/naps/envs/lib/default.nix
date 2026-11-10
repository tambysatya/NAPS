{flakeRoot, lib, inputs, ...}:

let
    utils = import "${flakeRoot}/lib" {inherit inputs lib;};


    initializeVMNetworking = config: vmname: env:
        lib.optionalAttrs (utils.isVM env) {
            ${vmname}.config = {
                    networking = {
                        defaultGateway = config.naps.topology.gateway;
                        nameservers = config.naps.topology.dns; # TODO useful ?
                        interfaces."enp1s0".ipv4 = {
                            addresses = [{address = utils.envIP env; prefixLength = 24;}];
                        };
                    };
            };
        };
    
    initializeContainerNetworking = config: ctname: env:
        let
            vmname = utils.envHostUID env;
        in lib.optionalAttrs (utils.isContainer env) {
            ${vmname}.config = {
                networking = {
                    nat = {
                        enable = true;
                        internalInterfaces = ["ve+"];
                        externalInterface = "enp1s0";
                        enableIPv6 = true;
                    };
                    interfaces."ve-${ctname}" = { #manually config the interface of the host;
                        ipv4 = {
                            addresses = [{address = utils.envPrivateHostIP env; prefixLength = 30;}];
                            routes = [{address = utils.envIP env; prefixLength=32;}];
                        };
                    };
                };
                containers.${ctname} = {
                    hostAddress = utils.envPrivateHostIP env;
                    privateNetwork = true;
                    config.networking = {
                        hostName = ctname;
                        firewall.enable = true; 
                        useHostResolvConf = lib.mkForce false;
                        defaultGateway = utils.envPrivateHostIP env;
                        nameservers = config.naps.topology.dns; # TODO useful ?
                        interfaces.eth0.ipv4.addresses = [ #eth0 is the default interface of containers
                            {address = utils.envIP env; prefixLength = 30;}
                        ];
                    };
                };
            };
        };

in utils // {
    inherit initializeVMNetworking initializeContainerNetworking;
}


