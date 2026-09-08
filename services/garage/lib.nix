{lib,pkgs, inputs, flakeRoot, ...}:

let
    utils = import "${flakeRoot}/lib" {inherit inputs lib;};
    bootstrapNode = ''
                    set -euo pipefail

                    if [ ! -f "/var/lib/garage/bootstrap-done" ]; then
                        echo "Bootstrap garage"

                            NODEID=`${pkgs.garage_2}/bin/garage node id`
                            SHORT_NODEID=''${NODEID:0:16}
                        if ! ${pkgs.garage_2}/bin/garage layout show | grep -q $SHORT_NODEID; then
                            ${pkgs.garage_2}/bin/garage layout assign -z dc1 -c 1G $NODEID
                                ${pkgs.garage_2}/bin/garage layout apply --version 1
                        else
                            echo "Skipping layout creation"
                        fi
                        touch /var/lib/garage/bootstrap-done
                    fi
    '';

    generateAccess = access@{bucket, ...}: #TODO: the key has the name of the bucket
                    ''
                if [ ! -f "/var/lib/garage/bootstrap-${bucket}" ]; then
                        if ! ${pkgs.garage_2}/bin/garage bucket info ${bucket}; then
                            echo "Creating bucket: ${bucket}"
                            ${pkgs.garage_2}/bin/garage bucket create ${bucket}
                        else
                            echo "Skipping bucket creation: ${bucket}"
                        fi
                        if ! ${pkgs.garage_2}/bin/garage key info ${bucket}; then
                            echo "Creating ${bucket} key"
                                ${pkgs.garage_2}/bin/garage key import --yes \
                                $(cat /var/lib/secrets/${utils.s3_key_id access})
                                $(cat /var/lib/secrets/${utils.s3_key access})
                                -n ${bucket}
                                ${pkgs.garage_2}/bin/garage bucket allow \
                                --read \
                                --write \
                                --owner \
                                ${bucket}\
                                --key ${bucket}
                        else
                            echo "Skipping creation ${bucket} [key already exists]"
                        fi

                touch /var/lib/garage/bootstrap-${bucket}
                fi
                    '';


        
        
in {
    inherit bootstrapNode generateAccess;
}
