{lib, inputs,...}:

let 
    libtypes = lib.types;
    filestypes = import ./files.nix {inherit lib inputs;};
    networktypes = import ./network.nix {inherit lib inputs;};
    envtypes= import ./deployement.nix {inherit lib inputs;}; 
    types = libtypes // filestypes // networktypes // envtypes;
in  with types; 
rec {
    secretType = types.enum [
        "plain"  # random generated string stored in /nix/store (world readable)
        "password"  # random generated string shipped by the provisioning server
        "ldapssha"  # random generated string shipped to the server + hashed and shipped to the LDAP servers
        "sslCertificate" # TLS certificate
        "postgres" # random generated string shipped to the server + the POSTGRES servers
        "s3" # random generated key-pair shipped to the server and the S3 servers
        "step-ca" # TLS certificate authority
        "nix-store" # nix-store binary-cache keypair
    ];
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
            path = lib.mkOption {
                description = "Installation path";
                type = types.str;
                default = "/var/lib/secrets";
            };
        };
    };





}
