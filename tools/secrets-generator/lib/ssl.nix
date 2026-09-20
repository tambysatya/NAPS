{lib, pkgs, ...}:

let
    git = ".secrets/git";
    plain = ".secrets/plain";

    generateCA = 
        domain:
        ''
        PWD=$(pwd)
        export STEPPATH="$PWD/${plain}/CA";
        mkdir -p ${plain}
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
                --provisioner=ca

            # Patching STEPPATH
            sed -i "s+$STEPPATH/secrets+/var/lib/secrets+" "$STEPPATH"/config/ca.json 
            sed -i "s+$STEPPATH/certs+/etc+" "$STEPPATH"/config/ca.json 
            sed -i "s+$STEPPATH+/var/lib/step-ca+" "$STEPPATH"/config/ca.json 

            ${lib.getExe pkgs.step-cli} certificate fingerprint "$STEPPATH/certs/root_ca.crt" \
                | tr -d '\n' \
                > "$STEPPATH/fingerprint" # step adds a \n at the end of the line
        fi
        mkdir -p ${git}
        cp "$STEPPATH/fingerprint" ${git}
        cp "$STEPPATH/config/ca.json" ${git}
        cp "$STEPPATH/certs/root_ca.crt" ${git}
        cp "$STEPPATH/certs/intermediate_ca.crt" ${git}

        cp "$STEPPATH/secrets/intermediate_ca_key" ${plain}
        cp "$STEPPATH/ca-password.key" ${plain}
        '';


    gen_ssl_certificate = crtname:
            ''
                PWD=$(pwd)
                export STEPPATH="$PWD/${plain}/CA";

                TARGET_PATH="${plain}"
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


in
{
    inherit generateCA gen_ssl_certificate;
}
