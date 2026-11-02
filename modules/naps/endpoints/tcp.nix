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

    generateForwardFrontend = 
        vmname:
        hosts: envname: 
        reached: # endpoints reached by the environment: Map EndpointName Endpoint
        let
            env = config.naps.internal.envs.all.${envname}; 
            mkFrontend = 
                epname: ep@{port, ...}:
                ''
                    frontend forward_tcp_${envname}_${epname}
                        mode tcp
                        bind ${utils.envPrivateHostIP env}:${lib.toString port}
                        default_backend forward_be_tcp_${epname}
                '';

                
        in utils.concatMapAttrsStringsSep "\n" mkFrontend reached;
    generateForwardBackend =  #Forward backends are shared per endpoint
        vmname: hosts: 
        forward: # Map Environment (Map EndpointName Endpoint)
        let
            
            allReachedEndpoints = lib.foldl' (attr: attr': attr // attr') {} (builtins.attrValues forward);
            mkBackend = epname: ep:
            ''
                backend forward_be_tcp_${epname}
                    mode tcp
                    ${utils.backendsConfig vmname ep (hosts.${epname})}
            '';
        in utils.concatMapAttrsStringsSep "\n" mkBackend allReachedEndpoints;

    generateForward = 
        vmenv: hosts: forward:
        let 
            vmname = utils.envUID vmenv;
            frontends = utils.concatMapAttrsStringsSep "\n" (generateForwardFrontend vmname hosts) forward;
            backends = generateForwardBackend vmname hosts forward;
        in ''
            # TCP Forward proxy
            ${frontends}
            ${backends}
        '';

    generateReverseFrontend =
        vmenv: epname: _:
        let
           ep = config.naps.internal.endpoints.all.tcp.${epname}; 
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
           ep = config.naps.internal.endpoints.all.tcp.${epname}; 
        in
        ''
            backend reverse_be_tcp_${epname}
                mode tcp
                ${utils.backendsConfig vmname ep exposed}
        '';
    generateReverse = 
        vmenv:
        consumers: 
        reverse: # Map Endpoint (Map InstanceName ServiceInstance)
        ''
            # TCP Reverse proxy
            ${utils.concatMapAttrsStringsSep "\n" (generateReverseFrontend vmenv) reverse}
            ${utils.concatMapAttrsStringsSep "\n" (generateReverseBackends (utils.envUID vmenv)) reverse}
        '';
    generateProxy =
        vmenv: hosts: consumers: {forward, reverse}:
        let

        in ''
            ${generateForward vmenv hosts forward}
            ${generateReverse vmenv consumers reverse}
        ''; #(forwardProxies ++ reverseProxies);
    generateFirewall =
        vmenv: {forward, reverse}:
        let
            processReverse =
                 epname: insname: ins: 
                 let
                    port = config.naps.internal.endpoints.tcp.${epname};
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

            mkForwardFw = 
                localenvuid: endpoints: 
                let
                    localenv = config.naps.internal.envs.all.${localenvuid};
                    allPorts = 
                        lib.unique 
                            (lib.mapAttrsToList (_: {port,...}: port) endpoints);
                    processPort =
                        port: {
                            ${utils.envUID vmenv}.${localenv.host.veth}.tcp= [port];
                        };
                in lib.optionalAttrs 
                    (utils.isContainer localenv) #open the forward port only for containers
                    lib.mkMerge (lib.mapAttrsToList processPort allPorts);
            allForwardFw = lib.mkMerge (lib.mapAttrsToList mkForwardFw forward);
        in lib.mkMerge [allReverseFw allForwardFw];
in {
    naps.endpoints.tcp = {
        inherit generateProxy;
    };
}


