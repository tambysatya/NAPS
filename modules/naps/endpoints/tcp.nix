{flakeRoot, lib, inputs, config, ...}:

/*

        - reverse_frontends: points to the local endpoints (and will be accessible 
          from the public addresses only). Opened if the endpoint is locally
          exposed.
        - forward_frontends: points to the global endpoints + local endpoins (and
          will be accessible from the private adresses only). Openned if the 
          endpoint is locally reached.

        Note that: for natively runned services, the forward proxy listens on 127.0.0.1.
        Therefore, services running natively should be bound to 127.0.0.2
*/

let
    types = import "${flakeRoot}/lib/types" {inherit lib inputs;};
    utils = import ./lib {inherit flakeRoot lib inputs;};
    endpointProxy =
        vmname: epname: ep@{hostname, port,...}:
        locally:
        globally:
        let
            localReached = locally.reachedBy;
            globalReached = globally.reachedBy;
            
            localExposed = locally.exposedBy;
            globalExposed = globally.exposedBy;
            
            localBind = lib.mapAttrsToList (_: ins: if utils.isContainer (utils.insEnv ins) then utils.insIP ins else "127.0.0.1:${lib.toString port}") localReached;
            globalBind = config.naps.topology.vms.${vmname}.ip;

            localIface = lib.mapAttrsToList (_: ins: if utils.isContainer (utils.insEnv ins) then ins.deployement.host.veth else "lo") localReached;
            interfaces = lib.optionals (localReached != []) localIface ++ lib.optionals (localExposed != []) ["eth0"];

            globalBackendIPs = map utils.insHostIP globalExposed;

            
            # If the endpoint is exposed by a local service, we create the reverse proxy
            reverseConfig = lib.optionalString (localExposed != []) ''
                frontend fe_reverse_tcp_${epname}
                    mode tcp
                    bind ${globalBind}:${lib.toString port}
                    default_backend be_reverse_tcp_${epname}
                backend be_reverse_tcp_${epname}
                    mode tcp
                    ${utils.backendsConfig vmname ep localExposed}
            '';

            # If the endpoint is reached by a local service, we create the forward proxy
            forwardConfig = lib.optionalString (localReached != []) ''
                frontend fe_forward_tcp_${epname}
                    mode tcp
                    bind ${utils.bindConfig vmname ep localReached}
                    default_backend be_forward_tcp_${epname}
                backend be_forward_tcp_${epname}
                    mode tcp
                    ${utils.backendsConfig vmname ep (localExposed // globalExposed)}
            '';

        in {
           config = [reverseConfig forwardConfig]; 
           firewall.${lib.toString port} = lib.optionalAttrs (interfaces != []) {
                proto = ["tcp"]; 
                inherit interfaces;
           };
        };

    generateProxy =
        vmname: alleps: # EndpointName -> {endpoint, globally, locally}
        let
            allProxies = lib.mapAttrsToList (epname: {endpoint, globally, locally}: endpointProxy vmname epname endpoint locally globally) alleps;
        in lib.mkMerge allProxies;
in {
    naps.endpoints.tcp = {
        inherit generateProxy;
    };
}


