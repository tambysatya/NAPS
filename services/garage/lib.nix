{lib,pkgs, inputs, flakeRoot, ...}:

let
    utils = import "${flakeRoot}/lib" {inherit inputs lib;};
    bootstrapNode = ''
                    set -euo pipefail
                    NODEID=`${pkgs.garage_2}/bin/garage node id`
                    SHORT_NODEID=''${NODEID:0:16}
                    if ! ${pkgs.garage_2}/bin/garage layout show | grep -q $SHORT_NODEID; then
                        ${pkgs.garage_2}/bin/garage layout assign -z dc1 -c 1G $NODEID
                            ${pkgs.garage_2}/bin/garage layout apply --version 1
                    else
                        echo "Skipping layout creation"
                    fi
    '';

    createKey = access@{bucket,...}:''
                    echo "Creating ${bucket} key"
                    ${pkgs.garage_2}/bin/garage key import --yes \
                        $(cat /var/lib/secrets/${utils.s3_root access}/${utils.s3_key_id access}) \
                        $(cat /var/lib/secrets/${utils.s3_root access}/${utils.s3_key access}) \
                        -n ${bucket} 
                    ${pkgs.garage_2}/bin/garage bucket allow \
                        --read \
                        --write \
                        --owner \
                        ${bucket}\
                        --key ${bucket}
    '';
    
    generateAccess = access@{bucket, ...}: #TODO: the key has the name of the bucket
                    ''
                    if ! ${pkgs.garage_2}/bin/garage bucket info ${bucket}; then
                        echo "Creating bucket: ${bucket}"
                        ${pkgs.garage_2}/bin/garage bucket create ${bucket}
                    else
                        echo "Skipping bucket creation: ${bucket}"
                    fi
                    if ! ${pkgs.garage_2}/bin/garage key info ${bucket}; then
                        echo "Creating ${bucket} key"
                        ${createKey access} 
                    else
                        OLD_KEY=$(${pkgs.garage_2}/bin/garage key info ${bucket}| ${lib.getExe pkgs.gawk} '/^Key ID:\s+(.*$)/ {print $3}')
                        NEW_KEY=$(cat /var/lib/secrets/${utils.s3_root access}/${utils.s3_key_id access})
                        if [[ "$OLD_KEY" == "$NEW_KEY" ]]; then
                            echo "Skipping creation ${bucket} [key already exists]"
                        else
                            echo "Replacing existing key of ${bucket}"
                            ${pkgs.garage_2}/bin/garage key delete $OLD_KEY --yes
                            ${createKey access}
                        fi
                    fi

                    '';


        
        
in {
    inherit bootstrapNode generateAccess;
}
