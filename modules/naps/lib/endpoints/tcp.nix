{flakeRoot, lib, inputs, config, ...}:
let
    utils = import ./lib {inherit flakeRoot lib inputs;};

    generateForwardFrontend =
        vmname:
        envname:
        {env, endpoints}: # endpoints reached by the environment: Map EndpointName Endpoint
        let
            mkFrontend =
                epname: ep@{port, ...}:
                ''
                    frontend forward_tcp_${envname}_${epname}
                        mode tcp
                        bind ${utils.envPrivateHostIP env}:${lib.toString port}
                        default_backend forward_be_tcp_${epname}
                '';


        in utils.concatMapAttrsStringsSep "\n" mkFrontend endpoints;
    generateForwardBackend =  #Forward backends are shared per endpoint
        vmname: allinstances:
        forward: # Map EnvironmentUID {env, (Map EndpointName Endpoint)}
        let

            endpointsPerEnv = lib.mapAttrsToList (_: {endpoints,...}: endpoints) forward;
            allReachedEndpoints = lib.foldl' (attr: attr': attr // attr') {} endpointsPerEnv;
            mkBackend = epname: ep:
            ''
                backend forward_be_tcp_${epname}
                    mode tcp
                    ${utils.backendsConfig vmname ep (allinstances.${epname}.instances)}
            '';
        in utils.concatMapAttrsStringsSep "\n" mkBackend allReachedEndpoints;

    generateForward =
        vmenv: allinstances : forward:
        let
            vmname = utils.envUID vmenv;
            frontends = utils.concatMapAttrsStringsSep "\n" (generateForwardFrontend vmname) forward;
            backends = generateForwardBackend vmname allinstances forward;
        in ''
            # TCP Forward proxy
            ${frontends}
            ${backends}
        '';

    generateReverseFrontend =
        vmenv: epname: {endpoint,...}:
        let
        in ''
            frontend reverse_tcp_${epname}
                mode tcp
                bind ${utils.envIP vmenv}:${lib.toString endpoint.port}
                default_backend reverse_be_tcp_${epname}

        '';
    generateReverseBackends =
        vmname: epname: 
        {endpoint, instances}: # Local services exposing the endpoint: Map InstanceName ServiceInstances
        ''
            backend reverse_be_tcp_${epname}
                mode tcp
                ${utils.backendsConfig vmname endpoint instances}
        '';
    generateReverse = 
        vmenv:
        reverse: # Map Endpoint (Map InstanceName ServiceInstance)
        ''
            # TCP Reverse proxy
            ${utils.concatMapAttrsStringsSep "\n" (generateReverseFrontend vmenv) reverse}
            ${utils.concatMapAttrsStringsSep "\n" (generateReverseBackends (utils.envUID vmenv)) reverse}
        '';
    generateProxy =
        vmenv: allinstances: forward: reverse:
        ''
            ${generateForward vmenv allinstances forward}
            ${generateReverse vmenv reverse}
        ''; 

in {
    naps.lib.endpoints.tcp= {
        # VMEnv -> Map Endpoint AllHosts -> Map EnvUID {env, endpoints} -> Map EndpointName {endpoint, instances}
        inherit generateProxy;
        generateFirewall = vmenv: reaches: exposes: {};
    };

}
