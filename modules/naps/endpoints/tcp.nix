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
        endpoints: # [(Endpoint, LinksHosts = [Env], RequestersEnv = [Env])]: LinksHosts = environment hosting the provider, Requesters = environments requesting access (= the native vm + some of the containers)
        let
           processEndpoint =
               tcp@{hostname, port}: providers: requesters:
               let
                    envIP = env: if utils.isContainer env then utils.envIP env else "127.0.0.1"; # if the env is a vm requesting the links, it corresponds to a service running natively
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
                            backend 

                        '';
               };
        in {

        };

in {

}


