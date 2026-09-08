{flakeRoot, lib, inputs,...}:

let
    utils = import "${flakeRoot}/lib" {inherit lib inputs;};
    installdir = "/mnt/var/lib/secrets";
    pemdir = "/mnt/var/lib/certs";

    installFile = 
        filename: owner: group: mode:
        let
            tgt = "${installdir}/${filename}"; 
        in ''
           cp "$1/${filename}" ${tgt}
           chown ${owner} ${tgt}
           chgrp ${group} ${tgt}
           chmod ${mode} ${tgt}
        '';

    installPassword = 
        {filename, owner, mode,...}: installFile filename owner owner mode;

    installLDAP = installPassword;
    installSSL = 
        {hostname,owner,...}:
        let 
            key = "${hostname}.key";
            crt = "${hostname}.crt";
        in ''
            ${installFile crt owner owner "0400"} 
            ${installFile key owner owner "0400"} 

            mkdir -p ${pemdir}
            cat ${installdir}/${crt} ${installdir}/${key} > ${pemdir}/${hostname}.pem
            chown ${owner} ${pemdir}/${hostname}.pem
            chmod 0400 ${pemdir}/${hostname}.pem


        '';

    installDB = 
        access@{database, owner,...}:
        installFile (utils.db_key access) owner "postgres" "0440"; #since only postgres is in the group postgres: the db can read safely all the certificates

    installS3 = 
        access@{bucket, owner,...}:
        ''
            ${installFile (utils.s3_key_id access) owner "garage" "0440"} 
            ${installFile (utils.s3_key access) owner "garage" "0440"}
        '';

    installStep = 
        _:
        ''
            ${installFile "ca-password.key" "step-ca" "step-ca" "0400"}
            ${installFile "intermediate_ca_key" "step-ca" "step-ca" "0400"}
        '';

    installSecret = 
        {type,content,...}:
        {
            "plain" = _: "";
            "password" = installPassword;
            "ldapssha" = installLDAP;
            "sslCertificate" = installSSL;
            "postgres" = installDB;
            "s3" = installS3;
            "step-ca" = installStep;
        }.${type} content;

    mkInstaller = vmsecrets:
    ''
        mkdir -p ${installdir}
        ${lib.concatMapStringsSep "\n" installSecret vmsecrets}
    '';
        
in
{
    inherit mkInstaller;
}
