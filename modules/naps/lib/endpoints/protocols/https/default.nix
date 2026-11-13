{flakeRoot, lib, inputs, config, ...}:
let
    utils = import ./lib {inherit flakeRoot lib inputs;};
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
    imports = [./reverse.nix ./forward.nix];
}
