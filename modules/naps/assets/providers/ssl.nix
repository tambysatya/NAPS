{flakeRoot, lib, inputs, pkgs, path, config, ...}:
let

    utils = import ./lib {inherit flakeRoot lib inputs path pkgs;};
    types = import "${flakeRoot}/lib" {inherit lib inputs;};
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
            args = {
                owner = "step-ca";
                group = "step-ca";
                mode = "0400";
            };
        in ''
            ${utils.install "${secname}/ca-password.key" "file" args}
            ${utils.install "${secname}/intermediate_ca_key" "file" args}
        '';
    
    installSSL = 
        secname:
        generateArgs@{hostname}:
        installArgs@{owner, group ? null, mode ? "0400", ...}:
        let
            group' = if group == null then owner else group;
        in
        ''
            install -d -o ${owner} -g ${group'} -m ${mode} /var/lib/secrets/${secname} 
            ${utils.install "${secname}/${hostname}.crt" "file" {inherit owner mode; group=group';}}
            ${utils.install "${secname}/${hostname}.key" "file" {inherit owner mode; group=group';}}
        '';

    installHAproxy= 
        secname:
        generateArgs@{hostname}:
        let pemdir = "/var/lib/certs";
            srcbasename = "$1/${secname}/${hostname}";
        in ''
            install -d -o haproxy -g haproxy -m 0400 ${pemdir} 
            cat ${srcbasename}.crt ${srcbasename}.key > ${pemdir}/${hostname}.pem
            chown haproxy ${pemdir}/${hostname}.pem
            chmod 0400 ${pemdir}/${hostname}.pem
        '';







in {
    naps.assets.providers.step-ca = {
        generate = acc: secname:  _:  [(generateCA domain)] ++ acc;
        install = secname: _: installCA secname;
    };
    naps.assets.providers.tls = {
        generate = acc: secname: {hostname}:  acc ++ [(gen_ssl_certificate hostname)];
        install = secname: args:
                  if args.installArgs.format == "step"
                  then installSSL secname args.generateArgs args.installArgs
                  else installHAproxy secname args.generateArgs;
    };
}
