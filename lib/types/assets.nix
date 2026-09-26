{lib, inputs,...}:

let
    envtypes= import ./deployement.nix {inherit lib inputs;}; 
    nettypes= import ./network.nix {inherit lib inputs;}; 
    filestypes= import ./files.nix {inherit lib inputs;}; 
    types = lib.types // envtypes // nettypes // filestypes;

in
rec {
    provider = types.enum [
        "plain"  # random generated string stored in /nix/store (world readable)
        "password"  # random generated string shipped by the provisioning server
        "ldapssha"  # random generated string shipped to the server + hashed and shipped to the LDAP servers
        "tls" # TLS certificate
        "haproxy" # TLS certificate in HAproxy format (public + private concatenated)
        "postgres" # random generated string shipped to the server + the POSTGRES servers
        "s3" # random generated key-pair shipped to the server and the S3 servers
        "step-ca" # TLS certificate authority
        "ssh-keygen" # SSH Key generation
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
    sslCertificate = types.submodule {
            options = {
                inherit (types) hostname reload;
            };
    };

    asset = types.submodule {
        options = {
            provider = lib.mkOption {
                description = "How to generate the asset";
                type = provider;
            };
            generateArgs = lib.mkOption {
                description = "Arguments passed to the generator.";
                type = types.attrs;
                default = {};
            };
            installArgs = lib.mkOption {
                description = "Arguments passed to the generator.";
                type = types.attrs;
                default = {};
            };
        };
    };

}
