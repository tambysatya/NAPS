{flakeRoot, lib, inputs, config, ...}:
let
    utils = import ../lib {inherit lib inputs flakeRoot;};
    topo = config.infra.topology;
    domain = topo.domain;
    iface = "enp1s0";
    hostDefaultAddress = "192.168.100.1";



    mkHosts =
        deploy:
        let proxyAddr = if deploy.env.type == "vm" then "127.0.0.1" else "192.168.100.1";
            caenvs = config.infra.deploy.endpoints."ca.${domain}";
        in 
        assert caenvs != [] || throw "step-ca service must be deployed";
        assert builtins.length caenvs == 1 || throw "step-ca service must be deployed once (no failover is implemented yet)"; #TODO
        let cauid = utils.envUID (lib.head caenvs).env;
        in {
            ${proxyAddr} = ["postgres.${domain}" "s3.${domain}" "ldap.${domain}"]; # all links are sent to the proxy
            ${config.infra.deploy.systems.${cauid}.ip} = ["ca.${domain}"];
            
            
        };

    generateNetworking = 
        name: deploy: if deploy.env.type == "vm" then generateVMNetworking name deploy else generateContainerNetworking name deploy;
   
    generateVMNetworking =
        vmname: deploy:
        {
            ${vmname}.config.networking = {
                hostName = vmname;
                dhcpcd.enable = false;
                firewall.enable = true;
                domain = domain;
                defaultGateway = {
                    address = topo.gateway;
                    interface = iface;
                };
                #nameservers = config.infra.topology.dns; # TODO useful ?
                hosts = mkHosts deploy;
                interfaces.${iface}.ipv4 = {
                    addresses = [
                        {address = deploy.ip; prefixLength = 24;} #TODO set prefixLength as a parameter ?
                    ];
                };
            };
        };

    generateContainerNetworking =
        ctname: deploy:
        let
            host = utils.envHost deploy.env;
            hostdeploy = config.infra.deploy.systems.${host};
        in{
            ${host}.config = {
                
                networking = {
                    nat = {
                        enable = true;
                        internalInterfaces = ["ve+"];
                        externalInterface = iface;
                        enableIPv6 = true;
                    };
                    interfaces."ve-${ctname}" = { #manually config the interface of the host;
                        ipv4.addresses = [
                            {address = hostDefaultAddress; prefixLength = 24;} 
                        ];
                    };
                };
                containers.${ctname} = {
                    hostAddress = hostDefaultAddress;
                    privateNetwork = true;
                };

            };
            ${ctname}.config = {
                networking = {
                    hostName = ctname;
                    useHostResolvConf = lib.mkForce false;
                    defaultGateway = hostDefaultAddress;
                    interfaces.eth0.ipv4.addresses = [ #eth0 is the default interface of containers
                        {address = deploy.ip; prefixLength = 24;}
                    ];
                    hosts = mkHosts deploy; #configure the proxy to connect on the host
                };
            };
        };

in {
    infra.outputs.systems = utils.mergeAll (lib.mapAttrsToList generateNetworking config.infra.deploy.systems);
}
