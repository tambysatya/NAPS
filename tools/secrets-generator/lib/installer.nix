{flakeRoot, lib, inputs, naps, pkgs, ...}:

let
    utils = import "${flakeRoot}/lib" {inherit lib inputs;};
    installdir = "/mnt/var/lib/secrets";
    pemdir = "/mnt/var/lib/certs";
    domain = naps.topology.domain;

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
            peminstall = ''
                mkdir -p ${pemdir}
                cat ${installdir}/${crt} ${installdir}/${key} > ${pemdir}/${hostname}.pem
                chown ${owner} ${pemdir}/${hostname}.pem
                chmod 0400 ${pemdir}/${hostname}.pem
            '';


        in ''
            ${installFile crt owner owner "0400"} 
            ${installFile key owner owner "0400"} 
            ${if owner == "haproxy" then peminstall else ""}
        '';

    mkPgPass = 
        access@{database, owner,...}:
        let str = "postgres.${domain}:5432:${database}:${database}";
            tgt = "${installdir}/${utils.db_key access}.pgpass";
        in
        ''
        CONTENT=$(cat "$1"/${utils.db_key access})
        echo "${str}:$CONTENT" > ${tgt}
        chown ${owner} ${tgt}
        chmod 0400 ${tgt}
        '';
    installDB = 
        access@{database, owner,...}:
        ''
        ${installFile (utils.db_key access) owner "postgres" "0440"} #since only postgres is in the group postgres: the db can read safely all the certificates
        ${mkPgPass access}
        '';

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
    
    installNixStore =
        _:
        ''
            [[ -f "$1/hydra-cache.key" ]] && ${installFile "hydra-cache.key" "hydra" "hydra" "0440"}
            [[ -f "$1/hydra-cache.pub" ]] && ${installFile "hydra-cache.pub" "root" "root" "0444"}
            if [[ -f "$1/hydra-ssh" ]]; then
                TGT=/mnt/var/lib/hydra/.ssh
                mkdir -p "$TGT"
                cp "$1/hydra-ssh" "$TGT"/id_ed25519
                cp "$1/hydra-ssh.pub" "$TGT"/id_ed25519.pub

                ${pkgs.openssh}/bin/ssh-keyscan -H github.com > "$TGT"/known_hosts #adding the github pubkey

                chown -R hydra:hydra "$TGT"

            fi
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
            "nix-store" = installNixStore;
        }.${type} content;

    mkInstaller = vmsecrets:
    ''
        set -euo pipefail
        mkdir -p ${installdir}
        ${lib.concatMapStringsSep "\n" installSecret vmsecrets}
    '';
        
in
{
    inherit mkInstaller;
}
