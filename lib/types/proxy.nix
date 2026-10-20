{lib, inputs, ...}:
let
    
    network = import ./network.nix {inherit lib inputs;};
    types = lib.types // network;


    firewallConfig = types.submodule {
        options = {
            interfaces = lib.mkOption {
                description = "On which interface the firewall should be openned. all = all the interfaces";
                type = types.either (types.enum ["all"]) (types.listOf types.str);
            };
            proto = lib.mkOption {
                description = "Allowed protocol";
                type = types.listOf (types.enum ["tcp" "udp"]);
                apply = lib.unique;
                default = [];
            };
        };
    };

    haproxyConfig = types.submodule {
        options = {
            config = lib.mkOption {
                description = "HAProxy configuration file";
                type = types.listOf types.str;
                default = [];
            };
            firewall = lib.mkOption {
                description = "Firewall configuration: Port -> firewallConfig";
                type = types.attrsOf firewallConfig;
                default = {};
            };
        };
    };
    proxy = types.submodule {
        options = {
            extraArgsType = lib.mkOption {
                description = "An endpoint contains {hostname, port, extraArgs}. This specifies the type of the user-defined extraArgs";
                type = types.nullOr types.raw;
                default = null;
            };
            generateProxy = lib.mkOption {
                description = "Given the set of all the endpoints of this type, generate a proxy configuration for this type of endpoint: perVM: vmname -> hosts -> consumers -> exposes -> reaches -> haproxyConfig";
                type = types.functionTo (types.functionTo (types.functionTo (types.functionTo (types.functionTo haproxyConfig))));
            };
        };
    };

in {
    inherit proxy haproxyConfig;
}

