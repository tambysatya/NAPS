{lib, inputs,...}:

let 
    libtypes = lib.types;
    filestypes = import ./files.nix {inherit lib inputs;};
    networktypes = import ./network.nix {inherit lib inputs;};
    envtypes= import ./deployement.nix {inherit lib inputs;}; 
    types = libtypes // filestypes // networktypes // envtypes;
in  with types; 
rec {

    opensslSize = lib.mkOption {
        description = "Length of the string to be generated using openssl rand";
        type = types.ints.positive;
        default = 64;
    };
    opensslType = lib.mkOption {
        description = "Type of the string to be generated using openssl rand";
        type = types.enum ["base64" "hex"];
    };
    plaintext = types.submodule { #will be world readable
            options = {
                inherit filename opensslSize opensslType;
            };
    };
    password = types.submodule {
            options = {
                inherit filename owner opensslSize opensslType;
                mode = types.filemode;
            };
    };
    sslCertificate = types.submodule {
            options = {
                inherit hostname owner reload;
            };
    };

    secretType = types.enum ["plain" "password" "ldapssha" "sslCertificate" "postgres" "s3" "step-ca"];

    secret = types.submodule {
        options = {
            type = lib.mkOption {
                description = "Type of the secret";
                type = secretType;
            };
            content = lib.mkOption {
                description = "Content of the secret. Must match the type";
                type = with types;
                        #nullOr (oneOf [plaintext password sslCertificate postgresAccess s3Access ldapSSHA]);
                        nullOr attrs; #TODO
            };
            recipients = lib.mkOption {
                description = "Identity names of the recipients.";
                type = types.listOf types.deployementEnvironment;
            };
        };
    };





}
