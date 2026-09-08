{flakeRoot, lib, inputs, pkgs, config, infra, vmname, ...}:

/* Configures the firewall of the vm */

let 
    utils = import "${flakeRoot}/lib" {inherit lib inputs;};
    deploy = infra.deploy.systems.${vmname};
    public_interface = "enp1s0";
    allInterfaces = config.networking.interfaces;

    getPorts = 
        proxyEntries:
        let frontends = lib.mapAttrsToList (_: {frontend, ...}: {inherit (frontend) ip port;}) proxyEntries;
            parts= lib.partition ({ip,...}: ip == "0.0.0.0") frontends; #right = openned everywhere, wrong = open only on the private interface
        in {world= map (builtins.getAttr "port") parts.right;
            local = map (builtins.getAttr "port") parts.wrong;};
    

    tcp = getPorts deploy.proxy.tcp;
    udp =  getPorts deploy.proxy.udp;
    http = if deploy.proxy.http != {} then [443] else [];

    generateFirewall =
        iface: _:
            if iface == public_interface
            then {
                allowedTCPPorts = tcp.world ++ http;
                allowedUDPPorts = udp.world;
            }
            else { # TODO all containers have access to all links, even these not requested by the service. Can be restricted
                allowedTCPPorts = tcp.world ++ tcp.local ++ http;
                allowedUDPPorts = udp.world ++ udp.local;
            };

in {

    config.networking.firewall.interfaces = lib.mapAttrs generateFirewall allInterfaces;

}
