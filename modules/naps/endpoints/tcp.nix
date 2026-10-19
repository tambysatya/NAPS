{flakeRoot, lib, inputs, config, ...}:

let
    types = import "${flakeRoot}/lib/types" {inherit lib inputs;};
    utils = import "${flakeRoot}/lib" {inherit lib inputs;};

    tcpEndpoint = types.submodule {
        options = {
            inherit (types) hostname port;
        };
    };
    generateProxy = 
        endpoints: # [(endpoint, providers = [ServiceInstance], requesters = [Env])]: ServiceInstance = environment hosting the provider (with priorities, tags,...), Requesters = environments requesting access (= the native vm + some of the containers)
        let
           processEndpoint =
               {endpoint, providers, requesters}:
               let
                    inherit (endpoint) hostname port;
                    envIP = env: if utils.isContainer env then utils.envIP env else "127.0.0.1"; # if the env is a vm requesting the links, it corresponds to a service running natively
                    sortedProviders = lib.sort (a: b: a.priority > b.priority) providers; # providers sorted by priority
                    mkBackendI = i: {ip,...}: "server be_tcp_${hostname}_${lib.toString port}_${i} ${ip}:${lib.toString port} check ${lib.optionalString (i > 1) "backup"}";
               in {
                    "frontend fe_tcp_${hostname}_${lib.toString port}" =
                        ''
                            mode tcp
                            bind ${lib.concatMapStringsSep " " envIP requesters}
                            backend be_tcp_${hostname}_${lib.toString port}
                        '';
                    "backend be_tcp_${hostname}_${lib.toString port}" = 
                        let
                        in ''
                            mode tcp
                            ${lib.concatStringsSep "\n"
                                (lib.imap mkBackendI sortedProviders)}

                        '';
               };
        in {

        };

in {

}


