{flakeRoot, lib, inputs, config, pkgs, ...}:
let
    utils = import "${flakeRoot}/lib" {inherit flakeRoot lib inputs;};
    types = lib.types;
    extraArgsType = types.submodule {
        options = {
            tls = lib.mkOption {
                description = ''
                    How TLS is implemented through HAproxy. 
                    Passthrough means that the service handles TLS while termination means that 
                    HAProxy terminates TLS and the endpoints receives an HTTP connection.
                '';
                type = types.enum ["passthrough" "termination"];
            };
        };
    };
    generateAssets = 
        {extraArgs,hostname,...}: 
        env:
        lib.optionalAttrs 
            (extraArgs.tls == "termination")
            {
                "tls".${hostname} = {
                        asset = {
                            generateArgs = {inherit hostname;};
                            installArgs = {
                                owner = "haproxy";
                                sslFormat = "haproxy";
                            };
                            reload = ["haproxy.service"];
                        };
                        recipients = [(utils.envHostUID env)];
                };
            };
in {
    naps.lib.endpoints.https = {
        inherit generateAssets extraArgsType;
        # VMEnv -> Map Endpoint AllHosts -> Map EnvUID {env, endpoints} -> Map EndpointName {endpoint, instances}
        generateProxy =  
            vmenv: allhosts: forward: reverse: "";
    };
}
