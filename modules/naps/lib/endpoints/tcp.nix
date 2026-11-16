{flakeRoot, lib, inputs, config, ...}:
{
    naps.lib.endpoints.tcp= {
        # VMEnv -> Map Endpoint AllHosts -> Map EnvUID {env, endpoints} -> Map EndpointName {endpoint, instances}
        generateProxy =  
            vmenv: allhosts: forward: reverse: "";
    };

}
