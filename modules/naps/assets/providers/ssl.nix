{flakeRoot, lib, inputs, pkgs, path, config, ...}:
let

    utils = import ./lib {inherit flakeRoot lib inputs path pkgs;};
    types = import "${flakeRoot}/lib/types" {inherit lib inputs;};
    paths = utils.paths;

    domain = config.naps.topology.domain;


    generateCA = 
        domain:
        ''
        PWD=$(pwd)
        export STEPPATH="$PWD/${paths.out}/step-ca";
        CA_NAME="ca.${domain}"

        if [[ ! -d $STEPPATH ]]; then
            install -d -m 711 "$STEPPATH"
            umask 077
            ${lib.getExe pkgs.openssl} rand -base64 48 \
                | tr -d '\n' \
                > "$STEPPATH"/ca-password.key
            ${lib.getExe pkgs.step-cli} ca init \
                --dns $CA_NAME \
                --name $CA_NAME \
                --password-file "$STEPPATH"/ca-password.key \
                --deployment-type standalone \
                --address :443 \
                --provisioner=ca \
                --no-db


            ${lib.getExe pkgs.step-cli} certificate fingerprint "$STEPPATH/certs/root_ca.crt" \
                | tr -d '\n' \
                > "$STEPPATH/fingerprint" # step adds a \n at the end of the line
        fi
        cp "$STEPPATH/fingerprint" ${paths.git}
        cp "$STEPPATH/certs/root_ca.crt" ${paths.git}
        cp "$STEPPATH/certs/intermediate_ca.crt" ${paths.git}

        cp "$STEPPATH/secrets/intermediate_ca_key" ${paths.out}
        cp "$STEPPATH/ca-password.key" ${paths.out}


        # Patching config
        cp "$STEPPATH/config/ca.json" ${paths.git}
        sed -i "s+$STEPPATH/secrets+/var/lib/secrets+" "${paths.git}"/ca.json
        sed -i "s+$STEPPATH/certs+/etc+" "${paths.git}"/ca.json 
        sed -i "s+$STEPPATH+/var/lib/step-ca+" "${paths.git}"/ca.json 
        '';


    gen_ssl_certificate = crtname:
            ''
                PWD=$(pwd)
                export STEPPATH="$PWD/${paths.out}/step-ca";

                TARGET_PATH="${paths.out}/${crtname}"
                mkdir -p "$TARGET_PATH"

                if [[ -f "$TARGET_PATH/${crtname}.key" ]]; then
                    rm "$TARGET_PATH/${crtname}.key"
                fi
                if [[ -f "$TARGET_PATH/${crtname}.crt" ]]; then
                    rm "$TARGET_PATH/${crtname}.crt"
                fi
                ${lib.getExe pkgs.step-cli} ca certificate \
                    --offline \
                    --provisioner ca \
                    --password-file "$STEPPATH/ca-password.key" \
                    --san ${crtname} \
                    ${crtname} "$TARGET_PATH/${crtname}.crt.tmp" "$TARGET_PATH/${crtname}.key" 

               cat "$TARGET_PATH/${crtname}.crt.tmp" "$STEPPATH/certs/intermediate_ca.crt" > "$TARGET_PATH/${crtname}.crt" #adding full-chain
               rm "$TARGET_PATH/${crtname}.crt.tmp";
            '';


    installCA =
        secname:
        let tgt = "/var/lib/secrets";
            args = name: {
                owner = "step-ca";
                group = "step-ca";
                mode = "0400";
                path = "${tgt}/${name}";
            };
        in ''
            ${utils.install "${secname}/ca-password.key" "file" (args "ca-password.key")}
            ${utils.install "${secname}/secrets/intermediate_ca_key" "file" (args "intermediate_ca_key")}
        '';
    
    installSSL = 
        secname:
        generateArgs@{hostname}:
        installArgs@{owner, path, ...}:
        let args = {inherit path; group = owner; owner = "root"; mode = "0750";}; # the certificate is owned by ROOT but belongs to the group of the service owner
        in ''
            ${utils.install "${secname}" "dir" args}
            chmod 0640 /mnt${path}/*
        '';

    installHAproxy= 
        secname:
        generateArgs@{hostname}:
        let pemdir = ''"$PREFIX"${utils.paths.pemdir}'';
            srcbasename = ''"$1"/${secname}/${hostname}'';
            owner = "root";
        in ''
            install -d -o ${owner} -g haproxy -m 0750 ${pemdir} 
            cat ${srcbasename}.crt ${srcbasename}.key > ${pemdir}/${hostname}.pem
            chown ${owner} ${pemdir}/${hostname}.pem
            chgrp -R haproxy ${pemdir}
            chmod 0640 ${pemdir}/${hostname}.pem
        '';







in {
    naps.assets.providers.step-ca = {
        apply = {
            generate = acc: secname:  _:  [(generateCA domain)] ++ acc;
            install = secname: _: installCA secname;
        };
    };
    naps.assets.providers.tls = {
        inputs = {
            installArgs = types.submodule {
                options = {
                    inherit (types) owner sslFormat;
                };
                freeformType = types.attrs;
            };
        };
        apply = {
            generate = acc: secname: {hostname}:  acc ++ [(gen_ssl_certificate hostname)];
            install = secname: args:
                      # HA proxy is installed if requested. Note that we still need to install the certificates in order
                      # to refresh it
                      ''
                        ${installSSL secname args.generateArgs args.installArgs}
                        ${lib.optionalString
                            (args.installArgs.sslFormat == "haproxy")
                            (installHAproxy secname args.generateArgs)}
                      '';
                      /*
                      if args.installArgs.sslFormat == "step"
                      then installSSL secname args.generateArgs args.installArgs
                      else installHAproxy secname args.generateArgs;
                      */
        };
    };
}
