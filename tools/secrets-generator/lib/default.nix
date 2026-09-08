{flakeRoot, lib,inputs, pkgs, infra, path, ...}:

let
    types = lib.types // (import "${inputs.self.outPath}/lib/types" {inherit lib inputs;});
    ssl = import ./ssl.nix {inherit lib inputs pkgs;};
    basic = import ./basic.nix {inherit lib inputs pkgs path;};
    install = import ./installer.nix {inherit lib inputs flakeRoot;};

    plain = ".secrets/plain";
    dstPath = filename: "${plain}/${filename}";
    
    generateSSLString = 
        {filename, opensslSize, opensslType,...}:
        ''
            [[ ! -f ${dstPath filename} ]] && ${lib.getExe pkgs.openssl} rand -${opensslType} ${lib.toString opensslSize} \
                                                | tr -d "\n" \
                                                > ${dstPath filename}
        '';
    
    processPlain = 
        content@{filename, ...}:
        ''
            ${generateSSLString content}
            cp .secrets/plain/${filename} .secrets/git/
        '';
    processPassword = 
        recipients:
        sslargs@{filename,...}:
        lib.concatStringsSep "\n"
            [
                (generateSSLString sslargs)
                (lib.concatMapStringsSep "\n" (basic.give filename) recipients)
            ];
        
    processS3Access =
        recipients: content@{bucket,...}:
        let id = "s3-${bucket}.id";
            key = "s3-${bucket}.key";
            genString = filename: generateSSLString {inherit filename; opensslSize=32; opensslType="hex";};
        in lib.concatStringsSep "\n"
            [
                (genString id)
                (genString key)
                (lib.concatMapStringsSep "\n" (basic.give id) recipients)
                (lib.concatMapStringsSep "\n" (basic.give key) recipients)
                "cp .secrets/plain/${id} .secrets/git"

            ];
    processPostgres = 
        recipients: {database,...}:
        let filename = "db-${database}.key";
        in lib.concatStringsSep "\n"
            [
                (generateSSLString {inherit filename; opensslSize = 64; opensslType = "base64";})
                (lib.concatMapStringsSep "\n" (basic.give filename) recipients)
            ];

    processLDAP = 
        recipients: content@{filename,...}:
        lib.concatStringsSep "\n" 
            [
                (generateSSLString content)
                (lib.concatMapStringsSep "\n" (basic.give filename) recipients)
                ''
                    cat ${plain}/${filename} \
                    | ${pkgs.openldap}/bin/slappasswd -s -- -h "{SSHA}" \
                    > ${plain}/${filename}.ssha

                    cp ${plain}/${filename}.ssha .secrets/git/
                ''
            ];
    processSSLCert =
        recipients: content@{hostname,...}:
        let
            crt = "${hostname}.crt";
            key = "${hostname}.key";
        in
        lib.concatStringsSep "\n" [
            (ssl.gen_ssl_certificate hostname)
            (lib.concatMapStringsSep "\n" (basic.give crt) recipients)
            (lib.concatMapStringsSep "\n" (basic.give key) recipients)
        ];
    

    processStep =
        recipients:
        let
            steppath = "${plain}/CA";
            
        in
        lib.concatStringsSep "\n" [
            (lib.concatMapStringsSep "\n" (basic.give "intermediate_ca_key") recipients)
            (lib.concatMapStringsSep "\n" (basic.give "ca-password.key") recipients)
        ];

    processSecret = 
        {type, content, recipients, ...}:
        {
             "plain" = processPlain content; #moved in git/
             "password" = processPassword recipients content;
             "ldapssha" = processLDAP recipients content;
             "postgres" = processPostgres recipients content;
             "s3" = processS3Access recipients content;
             "sslCertificate" = processSSLCert recipients content;
             "step-ca" = processStep recipients; # always generated first
        }.${type};



in {
    processSecrets = 
        ''
            mkdir -p ${plain}
            mkdir -p .secrets/provisioner/
            ${lib.concatMapStringsSep "\n" basic.generateIdentity infra.secrets.allEnvs}
            ${ssl.generateCA infra.topology.domain}
            ${lib.concatMapStringsSep "\n" processSecret infra.secrets.allSecrets}
            ${lib.concatMapStringsSep "\n" basic.ship (builtins.attrNames infra.topology.vms)}

            # Generate a certificate for the provisioning server
            ${ssl.gen_ssl_certificate infra.topology.provisionerAddr}
            mkdir -p .secrets/provisioner/ssl
            cp .secrets/plain/${infra.topology.provisionerAddr}.crt .secrets/provisioner/ssl
            cp .secrets/plain/${infra.topology.provisionerAddr}.key .secrets/provisioner/ssl


            # Generate the terranix configuration
            nix build ${path}#terranix -o terraform.tf.json.tmp
            cp terraform.tf.json.tmp terraform.tf.json
            chmod u+w terraform.tf.json
            rm terraform.tf.json.tmp

            #Replace the tokens with their value
            ${lib.concatMapStringsSep "\n" (basic.applyToken "terraform.tf.json") (builtins.attrNames infra.topology.vms)}
        '';

    inherit (install) mkInstaller;
}
