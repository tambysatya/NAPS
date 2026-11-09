{flakeRoot, lib, inputs, config, pkgs, ...}:

let
    utils = import "${flakeRoot}/lib" {inherit lib inputs;};
    types = lib.types // import "${flakeRoot}/lib/types" {inherit lib inputs;};
    access = types.submodule {
        options = {
            bucket = lib.mkOption {
                description = "Bucket name";
                type = types.str;
            };
            inherit (types) owner reload;
        };
    };
in {

naps.links.s3 = {
    inherit access;
    endpoints.https = [
        {hostname = "s3.${config.naps.topology.domain}"; port = 3900; extraArgs = {tls="termination";};}
    ];
    assets = env: hosts: access: {
        "password"."${utils.s3_key access}" = {
            asset = {
                generateArgs = {opensslSize = 64; opensslType = "hex";};
                installArgs = {inherit (access) owner; group="garage"; mode = "440";};
                inherit (access) reload;
            };
            recipients = [(utils.envUID env)] ++ map utils.envUID hosts;
        };
        "plain"."${utils.s3_key_id access}" = {
            asset = {
                generateArgs = {opensslSize = 64; opensslType = "hex";};
                inherit (access) reload;
            };
            recipients = [(utils.envUID env)] ++ map utils.envUID hosts;
        };
    };
    accessuid = utils.s3_root;
    waitLinkUp = 
        ''
        until ${pkgs.netcat}/bin/nc -z s3.${config.naps.topology.domain} 443; do
            echo "Testing s3 connectivity..."
            sleep 1
        done
        echo "Connected to s3."
        '';
};
}
