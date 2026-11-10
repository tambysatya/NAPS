{flakeRoot, lib, inputs,...}:

let
    types = lib.types // (import "${flakeRoot}/lib/types" {inherit lib inputs;});
    utils = import "${flakeRoot}/lib" {inherit inputs lib;};

    provider = types.submodule {
        options = {
            inputs = lib.mkOption {
                description = "Inputs types";
                type = types.submodule {
                    options = {
                        generateArgs = lib.mkOption {
                            description = "Types of the attrset passed to the generator. If set to null, any attrset is valid.";
                            type = types.raw;
                            default = null;
                        };
                        installArgs = lib.mkOption {
                            description = "Types of the attrset passed to the installer. If set to null, any attrset is valid.";
                            type = types.raw;
                            default = types.submodule {
                                options = {inherit (types) owner;};
                                freeformType = types.attrs;
                            };
                            defaultText = lib.literalExpression #to avoid stack overflow during doc generation
                                ''
                                    types.submodule {
                                      options = {
                                        inherit (types) owner;
                                      };
                                    }
                                '';
                        };
                    };
                };

            };
            apply = lib.mkOption {
                description = "Functions to generate and install assets";
                type = types.submodule {
                    options = {
                        generate = lib.mkOption {
                            description = "A function to generate the asset. Should have type: [String] -> assetname -> generatorEntry -> [String]. The first argument is an accumulator of all previously outputted scripts, allowing the generator to add its output BEFORE the others (useful e.g. for the CA which should be generated BEFORE the TLS certificates)";
                            type = types.functionTo (types.functionTo (types.functionTo (types.listOf types.str)));
                        };
                        install = lib.mkOption {
                            description = "A function to install the asset. Should have type: assetname -> installerEntry -> Script";
                            type = types.functionTo (types.functionTo types.str);
                        };
                        config = lib.mkOption {
                            description = ''
                                Extra Configuration appended to the system config.
                                Asset -> ConfigModule
                            '';
                            type = types.functionTo types.attrs;
                            default = asset: {};
                        };
                    };
                };
            };
        };
    };


in 

{
    options.naps.assets.providers = lib.mkOption {
        description = "A set of asset provisioner, declaring how to generate and install them";
        type = types.attrsOf provider;
        default = {};
    };
}
