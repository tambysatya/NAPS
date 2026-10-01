{flakeRoot, lib, inputs, config, pkgs, ...}:

/* Implements in-place assets updates */

let
    utils = import ../lib {inherit lib inputs flakeRoot;};

    fetchSecretScript = 
        {installArgs, ...}: {

        };

    installSecretScript = 
        {

        };
    processAsset =
        {installArgs, reload, ...}: {

        };

in {

}


