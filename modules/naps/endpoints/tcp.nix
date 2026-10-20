{flakeRoot, lib, inputs, config, ...}:

let
    types = import "${flakeRoot}/lib/types" {inherit lib inputs;};
    utils = import "${flakeRoot}/lib" {inherit lib inputs;};

    displayBackendIP = ep@{hostname, port,...}: i: ins: "server be_tcp_${hostname}_${lib.toString port}_${lib.toString i} ${utils.envIP (utils.serviceEnv ins)}:${lib.toString port} check ${lib.optionalString (i > 1) "backup"}";

    processExposedEndpointFrontend = # ep: a given endpoint. epConsumers, epHosts: all the consumers/hosts instances of the endpoint
        vmname: epname: ep@{hostname, port, ...}: epConsumers: epHosts: 
        let
            consumersEnvs = lib.mapAttrsToList (insname: ins: ins.deployement) epConsumers;
            consumersHosts = map utils.envHost consumersEnvs;
            isConsumedLocally = builtins.length (lib.unique consumersHosts) == 1;
            listen = if isConsumedLocally 
                        then map (env: if utils.isContainer env then utils.envIP env else "127.0.0.1") consumersEnvs
                        else ["0.0.0.0"];
            isHostedNatively = builtins.elem vmname (map utils.envUID consumersEnvs); # if hosted natively, no proxy is created (we only open the firewall)

        in {
            config = lib.optionals (! isHostedNatively)
                [
                ''
                    frontend reverse_fe_tcp_${hostname}_${lib.toString port}
                        mode tcp
                        bind ${lib.concatMapStringsSep "," (ip: "${ip}:${lib.toString port}") listen}
                        default_backend "be_tcp_${hostname}_${lib.toString port}
                ''];
            firewall.${lib.toString port} = {
                proto = ["tcp"];
                interfaces = 
                    if isConsumedLocally
                    then map (env: if utils.isContainer env then env.host.veth else "lo") consumersEnvs
                    else "all";
            };
        };

    processExposedEndpointBackend = 
        vmname: hosts: epname: ep@{hostname, port, ...}:
        let
            epLocalHosts = lib.filterAttrs (_: ins: utils.envHost (utils.serviceEnv ins) == vmname) hosts;
            sortedHosts = lib.sort (ins: ins': ins.priority > ins'.priority) (builtins.attrValues epLocalHosts);
        in {
            config = [
            ''
                backend be_tcp_${hostname}_${lib.toString port}
                    mode tcp
                    ${lib.concatStringsSep "\n" (lib.imap (displayBackendIP ep) sortedHosts)}
            ''
            ];
        };



    processReachedEndpointFrontend =
        vmname: epname: ep@{hostname, port, ...}: epConsumers:
        let
            consumersEnvs = lib.mapAttrsToList (insname: ins: ins.deployement) epConsumers;
            localConsumers = lib.filter (env: utils.envHost env == vmname) consumersEnvs;
            localConsumersIP = map (env: if utils.isContainer env then utils.envIP env else "127.0.0.1") localConsumers;
            localConsumersIface = map (env: if utils.isContainer env then env.host.veth else "lo") localConsumers;
        in {

            config = [''
                frontend proxy_fe_tcp_${hostname}_${lib.toString port}"
                    mode tcp
                    bind ${lib.concatMapStringsSep "," (ip: "${ip}:${lib.toString port}") localConsumersIP}
                    default_backend be_tcp_${hostname}_${lib.toString port}
            ''];
            firewall.${lib.toString port} = {
                    proto = ["tcp"];
                    interfaces = localConsumersIface;
            };

        };
    processReachedEndpointBackend = 
        epname: ep@{hostname, port,...}: epHosts:
        let
            hostsIns = builtins.attrValues epHosts;
            sortedHosts = lib.sort (ins: ins': ins.priority > ins'.priority) hostsIns;
        in {
            config = [''
                backend be_tcp_${hostname}_${lib.toString port}
                    mode tcp
                    ${lib.concatStringsSep "\n" (lib.imap (displayBackendIP ep) sortedHosts)}
            ''];
        };
    generateProxy =
        vmname: hosts: consumers: exposes: reaches:
        let
            feExposed = lib.mapAttrsToList 
                            (epname: ep: 
                                processExposedEndpointFrontend 
                                    vmname epname ep 
                                    (consumers.${epname} or {})
                                    (hosts.${epname} or {})) 
                            exposes;
            beExposed = lib.mapAttrsToList (epname: ep: processExposedEndpointBackend vmname (hosts.${epname} or {}) epname ep) exposes;

            feReached = lib.mapAttrsToList (epname: ep: processReachedEndpointFrontend vmname epname ep (consumers.${epname} or {})) reaches;
            beReached = lib.mapAttrsToList (epname: ep: processReachedEndpointBackend epname ep (hosts.${epname} or {})) reaches;
        in
           lib.mkMerge (feExposed ++ feReached ++ beExposed ++ beReached);
           #lib.mkMerge (feReached ++ beExposed ++ beReached);
in {
    naps.endpoints.tcp = {
        inherit generateProxy;
    };
}


