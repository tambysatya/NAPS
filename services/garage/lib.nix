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
                    #if ! ${pkgs.garage_2}/bin/garage bucket info ${bucket}; then
                    if [[ -z "$(${pkgs.garage_2}/bin/garage bucket list | grep ${bucket})" ]]; then
                        echo "Creating bucket: ${bucket}"
                        ${pkgs.garage_2}/bin/garage bucket create ${bucket}
                    else
                        echo "Skipping bucket creation: ${bucket}"
                    fi
                    
                    OLD_KEY=$(${pkgs.garage_2}/bin/garage key list | ${lib.getExe pkgs.gawk} '$3 == "${bucket}" {print $1}')
                    NEW_KEY=$(cat /var/lib/secrets/${utils.s3_root access}/${utils.s3_key_id access})
                    if [[ "$OLD_KEY" != "$NEW_KEY" ]]; then
                        if [[ -n "$OLD_KEY" ]]; then
                            echo "Replacing existing key for ${bucket}"
                            ${pkgs.garage_2}/bin/garage key delete $OLD_KEY --yes
                        else
                            echo "Creating a new key for ${bucket}
                        fi
                        ${createKey access}
                    fi
                    '';


        
        
in {
    inherit bootstrapNode generateAccess;
}
