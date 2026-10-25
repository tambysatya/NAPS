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
    mkForwardBackend =  #Forward backends are shared per endpoint
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
            backends = mkForwardBackend vmname hosts forward;
        in ''
            # Forward proxy
            ${frontends}
            ${backends}
        '';
    generateReverse = 
        vmenv:
        consumers: epname: 
        exposed: # Local services exposing the endpoint: Map InstanceName ServiceInstances
        "";
    generateProxy =
        vmenv: hosts: consumers: {forward, reverse}:
        let
            forwardProxies = lib.mapAttrsToList (generateForwardFrontend vmenv hosts) forward; 
            reverseProxies = lib.mapAttrsToList (generateReverse vmenv consumers) reverse;

        in generateForward vmenv hosts forward; #(forwardProxies ++ reverseProxies);
in {
    naps.endpoints.tcp = {
        inherit generateProxy;
    };
}


