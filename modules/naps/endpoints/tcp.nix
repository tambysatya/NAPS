{flakeRoot, lib, inputs, config, ...}:

/*

        - reverse_frontends: points to the local endpoints (and will be accessible from the public addresses only)
        - forward_frontends: points to the global endpoints + local endpoins (and will be accessible from the private adresses only)

        Note that: for natively runned services, the forward proxy listens on 127.0.0.1. Therefore, service running natively should be
        bound to 127.0.0.2
*/

let
    types = import "${flakeRoot}/lib/types" {inherit lib inputs;};
    utils = import ./lib {inherit flakeRoot lib inputs;};

    backendConfig = 
        vmname: ep@{hostname, port,...}: i: ins: 
        let 
            env = utils.insEnv ins;
            ip = if utils.envUID env == vmname then "127.0.0.2" else utils.envIP env;
        in "server be_tcp_${hostname}_${lib.toString port}_${lib.toString i} ${ip}:${lib.toString port} check ${lib.optionalString (i > 1) "backup"}";
    backendsConfig = vmname: ep: instances:
        let sorted = lib.sort (ins: ins': ins.priority > ins'.priority) instances;
        in lib.concatStringsSep "\n" (lib.imap (backendConfig vmname ep) sorted);

    bindConfig = vmname: ep@{port,...}: instances:
        let getIP = ins@{deployement, ...}:
                if utils.envUID deployement == vmname 
                then "127.0.0.1:${lib.toString port}" 
                else "${deployement.host.privateHostAddress}:${lib.toString port}"; 
        in lib.concatMapStringsSep 
            ", " 
            getIP
            instances;

    endpointProxy =
        vmname: epname: ep@{hostname, port,...}:
        locally:
        globally:
        let
            localReached = builtins.attrValues locally.reachedBy;
            globalReached = builtins.attrValues globally.reachedBy;
            
            localExposed = builtins.attrValues locally.exposedBy;
            globalExposed = builtins.attrValues globally.exposedBy;
            
            localBind = map (ins: if utils.isContainer (utils.insEnv ins) then utils.insIP ins else "127.0.0.1:${lib.toString port}") localReached;
            globalBind = config.naps.topology.vms.${vmname}.ip;

            localIface = map (ins: if utils.isContainer (utils.insEnv ins) then ins.deployement.host.veth else "lo") localReached;
            interfaces = localIface ++ lib.optionals (globalReached != []) ["eth0"];

            globalBackendIPs = map utils.insHostIP globalExposed;

            
            reverseConfig = lib.optionalString (localExposed != []) ''
                frontend fe_reverse_tcp_${epname}
                    mode tcp
                    bind ${globalBind}:${lib.toString port}
                    default_backend be_reverse_tcp_${epname}
                backend be_reverse_tcp_${epname}
                    mode tcp
                    ${backendsConfig vmname ep localExposed}
            '';

            forwardConfig = ''
                frontend fe_forward_tcp_${epname}
                    mode tcp
                    bind ${bindConfig vmname ep localReached}
                    default_backend be_forward_tcp_${epname}
                backend be_forward_tcp_${epname}
                    mode tcp
                    ${backendsConfig vmname ep (localExposed ++ globalExposed)}
            '';

        in {
           config = [reverseConfig forwardConfig]; 
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


