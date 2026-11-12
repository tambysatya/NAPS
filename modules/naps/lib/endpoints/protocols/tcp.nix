{flakeRoot, lib, inputs, config, ...}:

/*

        We create one forward proxy per local Environment. The fw proxy 
        dedicated for natives services listens on 127.0.0.1 and points.

        Native endpoints should be listening on 127.0.0.2 to avoid clashes when
        an endpoint is both exposed and reached by natives services.

*/

let
    types = import "${flakeRoot}/lib/types" {inherit lib inputs;};
    utils = import ./lib {inherit flakeRoot lib inputs;};

    generateReverseFrontend =
        vmenv: epname: _:
        let
           ep = config.naps.endpoints.all.tcp.${epname}; 
        in ''
            frontend reverse_tcp_${epname}
                mode tcp
                bind ${utils.envIP vmenv}:${lib.toString ep.port}
                default_backend reverse_be_tcp_${epname}

        '';
    generateReverseBackends =
        vmname: epname: 
        exposed: # Local services exposing the endpoint: Map InstanceName ServiceInstances
        let
           ep = config.naps.endpoints.all.tcp.${epname}; 
        in
        ''
            backend reverse_be_tcp_${epname}
                mode tcp
                ${utils.backendsConfig vmname ep exposed}
        '';
    generateReverse = 
        vmenv:
        reverse: # Map Endpoint (Map InstanceName ServiceInstance)
        ''
            # TCP Reverse proxy
            ${utils.concatMapAttrsStringsSep "\n" (generateReverseFrontend vmenv) reverse}
            ${utils.concatMapAttrsStringsSep "\n" (generateReverseBackends (utils.envUID vmenv)) reverse}
        '';
    reverseProxy =
        vmenv: reverse:
        let

        in ''
            ${generateReverse vmenv reverse}
        ''; #(forwardProxies ++ reverseProxies);
    reverseFirewall =
        vmenv: reverse:
        let
            processReverse =
                 epname: insname: ins: 
                 let
                    port = config.naps.endpoints.all.tcp.${epname}.port;
                 in lib.mkMerge [
                    (lib.optionalAttrs (utils.runsInContainer ins) 
                     {
                        ${utils.insEnvUID ins}."eth0".tcp = [port];
                     })
                    {
                        ${utils.envUID vmenv}."enp1s0".tcp = [port];
                    }
                 ];

            mkReverseFw = 
                endpoint: instances: 
                    lib.mkMerge (lib.mapAttrsToList (processReverse endpoint) instances);
            allReverseFw = lib.mkMerge (lib.mapAttrsToList mkReverseFw reverse);
        in allReverseFw;
in {
    naps.lib.endpoints.tcp = {
        inherit reverseProxy reverseFirewall;
    };
}


