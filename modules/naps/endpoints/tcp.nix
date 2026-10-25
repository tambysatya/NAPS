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

    generateForward = 
        vmenv:
        hosts: envname: 
        reached: # endpoints reached by the environment: Map EndpointName Endpoint
        let
            vmname = utils.envUID vmenv;
            env = config.naps.internal.envs.all.${envname}; 
            processEndpoint = 
                epname: ep@{port, ...}:
                ''
                    frontend forward_tcp_${envname}_${epname}
                        mode tcp
                        bind ${utils.envPrivateHostIP env}:${lib.toString port}
                        default_backend forward_be_tcp_${envname}_${epname}
                    backend forward_be_tcp_${envname}_${epname}
                        mode tcp
                        ${utils.backendsConfig vmname ep (hosts.${epname})}
                '';
        in utils.concatMapAttrsStringsSep "\n" processEndpoint reached;
    generateReverse = 
        vmenv:
        consumers: epname: 
        exposed: # Local services exposing the endpoint: Map InstanceName ServiceInstances
        "";
    generateProxy =
        vmenv: hosts: consumers: {forward, reverse}:
        let
            forwardProxies = lib.mapAttrsToList (generateForward vmenv hosts) forward; 
            reverseProxies = lib.mapAttrsToList (generateReverse vmenv consumers) reverse;
        in lib.concatStringsSep "\n" forwardProxies; #(forwardProxies ++ reverseProxies);
in {
    naps.endpoints.tcp = {
        inherit generateProxy;
    };
}


