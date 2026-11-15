{flakeRoot, lib, inputs, config, ...}:
{
    naps.lib.endpoints.tcp= {
        reverseProxy = vmenv: epIR: "";
        forwardProxy = vmenv: allhosts: envIR: "";
    };

}
