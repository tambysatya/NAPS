{flakeRoot, lib, inputs, config, ...}:

let
    types = import "${flakeRoot}/lib/types" {inherit lib inputs;};
    utils = import ./lib {inherit flakeRoot lib inputs;};

    displayBackendIP = ep@{hostname, port,...}: i: ins: "server be_tcp_${hostname}_${lib.toString port}_${lib.toString i} ${utils.envIP (utils.serviceEnv ins)}:${lib.toString port} check ${lib.optionalString (i > 1) "backup"}";

    forwardProxy =
        epname: ep@{hostname, port}:
        locally:
        globally:
        let
        in {};
    reverseProxy =
        vmname: epname: ep@{hostname, port, ...}:
        locally:
        globally:
        let
            lExposed = builtins.attrValues locally.exposedBy; # [ServiceInstances]
            # Reverse proxy: the backends are the local services (sorted by priority)
            backendIPs = 
                map 
                    (ins: if utils.isContainer (utils.insEnv ins) 
                          then utils.insIP ins
                          else "127.0.0.1") 
                    (lib.sort (ins: ins': ins.priority > ins'.priority) lExposed);
            #localBackendIPs = map (ins: if utils.isContainer (utils.insEnv ins) then utils.insIP ins else "127.0.0.1:${lib.toString port}") lExposed;
            #globalBackendIPs = map utils.insHostIP gExposed;
            #gExposed = builtins.attrValues globally.exposedBy; # [ServiceInstances]
            #backendIPs = localBackendIPs; #++ globalBackendIPs; # the reverse proxy points only to local IPs

            lReached = builtins.attrValues locally.reachedBy;
            gReached = builtins.attrValues globally.reachedBy;
            localBind = map (ins: if utils.isContainer (utils.insEnv ins) then utils.insIP ins else "127.0.0.1:${lib.toString port}") lReached;
            globalBind = [config.naps.topology.vms.${vmname}.ip];
            bindIPs = localBind ++ lib.optionals (gReached != []) globalBind;

            localIface = map (ins: if utils.isContainer (utils.insEnv ins) then ins.deployement.host.veth else "lo") lReached;
            interfaces = localIface ++ lib.optionals (gReached != []) ["eth0"];
        in lib.optionalAttrs (backendIPs != []) 
        {
            config = [''
                frontend reverse_tcp_${epname}
                    mode tcp
                    bind ${lib.concatStringsSep 
                                ", " 
                                (if bindIPs == [] then ["0.0.0.0:${lib.toString port} # TODO this endpoint is exposed globally since it is not consumed by any service in NAPS."] else bindIPs)}
                    default_backend reverse_be_tcp_${epname}
                backend reverse_be_tcp_${epname}
                    mode tcp
                    ${lib.concatStringsSep "\n"
                        (lib.imap (i: ip: "server be_tcp_${epname}_${lib.toString i} ${ip}:${lib.toString port} check ${lib.optionalString (i > 1) "backup"}") backendIPs)}

            ''];
            firewall.${lib.toString port} = {
                proto = ["tcp"];
                interfaces = if interfaces == [] then "all" else interfaces; #TODO if an endpoint is not consumed, the firewall won't be oppened. In this case, we default it to an oppened world service
            };
        };
    generateProxy =
        vmname: alleps: # EndpointName -> {endpoint, globally, locally}
        let
            reverse = lib.mapAttrsToList (epname: {endpoint, globally, locally}: reverseProxy vmname epname endpoint locally globally) alleps;
        in lib.mkMerge reverse;
in {
    naps.endpoints.tcp = {
        inherit generateProxy;
    };
}


