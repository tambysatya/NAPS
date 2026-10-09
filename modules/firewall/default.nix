{flakeRoot, lib, inputs, pkgs, config, naps, vmname, ...}:

/* Configures the firewall of the vm */

let 
    utils = import "${flakeRoot}/lib" {inherit lib inputs;};
    public_interface = "enp1s0";
    allInterfaces = config.networking.interfaces;

    getPorts =
        proxyEntries: 
        let parts = utils.partitionAttrs (port: {frontend,...}: frontend.public) proxyEntries;
        in {world = map builtins.fromJSON (builtins.attrNames parts.right);
            local = map builtins.fromJSON (builtins.attrNames parts.wrong);};

    tcp = getPorts naps.deploy.systems.${vmname}.proxy.tcp;
    udp =  getPorts naps.deploy.systems.${vmname}.proxy.udp;
    http = if lib.filterAttrs (_: {public,...}: public) naps.deploy.systems.${vmname}.proxy.http != {} # HTTP is opened publicly only if at least one service is hosted.
           then [443] else [];

    generateFirewall =
        iface: _:
            if iface == public_interface
            then {
                allowedTCPPorts = tcp.world ++ http;
                allowedUDPPorts = udp.world;
            }
            else { # TODO all containers have access to all links, even these not requested by the service. Can be restricted
                allowedTCPPorts = tcp.world ++ tcp.local ++ [443];
                allowedUDPPorts = udp.world ++ udp.local;
            };

in {

    config.networking.firewall = if naps.envs.all.${vmname}.type == "vm"
                                 then {interfaces = lib.mapAttrs generateFirewall allInterfaces;}
                                 else {enable = false;}; #on containers, the firewall is disabled

}
