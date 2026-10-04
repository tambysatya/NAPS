{flakeRoot, lib, inputs, pkgs, path,...}:
let
    utils = import "${flakeRoot}/lib" {inherit lib inputs;};
    ship = 
        name:
        let 
            path = utils.paths.perVM;
            provisioner = ".secrets/provisioner/secrets";
            tokens = ".secrets/tokens";
        in ''
            mkdir -p ${provisioner}
            mkdir -p ${tokens}
            tar -cvf ${path}/${name}.tar -C ${path}/${name} .
            ${lib.getExe pkgs.gzip} ${path}/${name}.tar

            TOKEN=$(${lib.getExe pkgs.openssl} rand -hex 64)
            cp ${path}/${name}.tar.gz "${provisioner}/$TOKEN.tar.gz"
            echo "$TOKEN" > "${tokens}/${name}.token"

            # to the mTLS server
            mkdir -p .secrets/provisioner/mtls
            mv ${path}/${name}.tar.gz ".secrets/provisioner/mtls/vm-${name}.tar.gz"
        '';

    applyToken = 
        terraformConfPath: name:
        let tokenpath = ".secrets/tokens/${name}.token";
        in ''
            TOKEN=$(cat ${tokenpath})
            sed -i "s/${lib.toUpper name}_TOKEN/$TOKEN/" ${terraformConfPath}
        '';
        
    gen_ssl_certificate = crtname:
            ''
                PWD=$(pwd)
                export STEPPATH="$PWD/${utils.paths.out}/step-ca";
                TARGET_PATH=".secrets/provisioner/ssl"
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
utils // {
    inherit ship applyToken gen_ssl_certificate;
}
