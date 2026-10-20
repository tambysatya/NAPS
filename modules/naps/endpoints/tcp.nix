{flakeRoot, lib, inputs, config, ...}:

let
    types = import "${flakeRoot}/lib/types" {inherit lib inputs;};
    utils = import "${flakeRoot}/lib" {inherit lib inputs;};

    displayBackendIP = ep@{hostname, port,...}: i: ins: "server be_tcp_${hostname}_${lib.toString port}_${lib.toString i} ${utils.envIP (utils.serviceEnv ins)}:${lib.toString port} check ${lib.optionalString (i > 1) "backup"}";

    processExposedEndpointFrontend = # ep: a given endpoint. epConsumers : all the consumers instances of the endpoint
        epname: ep@{hostname, port, ...}: epConsumers: 
        let
            consumersEnvs = lib.mapAttrsToList (insname: ins: ins.deployement) epConsumers;
            consumersHosts = map utils.envHost consumersEnvs;
            isConsumedLocally = builtins.length (lib.unique consumersHosts) == 1;

        in {
            "rev_fe_tcp_${hostname}_${lib.toString port}" = {
                mode = "tcp";
                bind.listen = 
                    if isConsumedLocally 
                    then map (env: if utils.isContainer env then utils.envIP env else "127.0.0.1") consumersEnvs
                    else ["0.0.0.0"];
                backend = "be_tcp_${hostname}_${lib.toString port}";
                firewall = {
                    inherit port;
                    interfaces = 
                        if isConsumedLocally
                        then map (env: if utils.isContainer env then env.host.veth else "lo") consumersEnvs
                        else "all";
                };
            };
        };

    processExposedEndpointBackend = 
        vmname: hosts: epname: ep@{hostname, port, ...}:
        let
            epLocalHosts = lib.filterAttrs (_: ins: utils.envHost (utils.serviceEnv ins) == vmname) hosts;
            sortedHosts = lib.sort (ins: ins': ins.priority > ins'.priority) (builtins.attrValues epLocalHosts);
        in {
            "be_tcp_${hostname}_${lib.toString port}" = {
                mode = "tcp";
                extraConfig = lib.imap (displayBackendIP ep) sortedHosts;
            };
        };



    processReachedEndpointFrontend =
        vmname: epname: ep@{hostname, port, ...}: epConsumers:
        let
            consumersEnvs = lib.mapAttrsToList (insname: ins: ins.deployement) epConsumers;
            localConsumers = lib.filter (env: utils.envHost env == vmname) consumersEnvs;
            localConsumersIP = map (env: if utils.isContainer env then utils.envIP env else "127.0.0.1") localConsumers;
            localConsumersIface = map (env: if utils.isContainer env then env.host.veth else "lo") localConsumers;
        in {
           "prox_fe_tcp_${hostname}_${lib.toString port}" = {
                mode = "tcp";
                bind.listen = localConsumersIP;
                backend = "be_tcp_${hostname}_${lib.toString port}";
                firewall = {
                    inherit port;
                    interfaces = localConsumersIface;
                };
           };
        };
    processReachedEndpointBackend = 
        epname: ep@{hostname, port,...}: epHosts:
        let
            hostsIns = lib.mapAttrsToList (insname: ins: ins.deployement) epHosts;
            sortedHosts = lib.sort (ins: ins': ins.priority > ins'.priority) hostsIns;
        in {
            "be_tcp_${hostname}_${lib.toString port}" = {
                mode = "tcp";
                extraConfig = builtins.trace sortedHosts (lib.imap (displayBackendIP ep) sortedHosts);
            };
        };
    generateProxy =
        vmname: hosts: consumers: exposes: reaches:
        let
            feExposed = lib.mapAttrsToList (epname: ep: processExposedEndpointFrontend epname ep (consumers.${epname} or {})) exposes;
            beExposed = lib.mapAttrsToList (epname: ep: processExposedEndpointBackend vmname (hosts.${epname} or {}) epname ep) exposes;

            feReached = lib.mapAttrsToList (epname: ep: processReachedEndpointFrontend vmname epname (consumers.${epname} or {})) reaches;
            beReached = lib.mapAttrsToList (epname: ep: processReachedEndpointBackend epname ep (hosts.${epname} or {})) reaches;
        in
        {
            frontends = lib.mkMerge feExposed; # ++ feReached);
            #backends = lib.mkMerge (beExposed ++ beReached);
        };
in {
    naps.endpoints.tcp = {
        inherit generateProxy;
    };
}


