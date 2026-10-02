{flakeRoot, lib, inputs, config, pkgs, ...}:

/* Implements in-place assets updates */

let
    utils = import ../lib {inherit lib inputs flakeRoot;};

    fetchAssetsScript = 
        vmname:
        let crt_basename= "vm-${vmname}";
        in ''
            curl --cert ${utils.ssl_crt_path crt_basename} \
                 --key  ${utils.ssl_key_path crt_basename} \
                 --cacert /etc/nixos/root_ca.crt \
                 --output /root/assets.tar.gz \
                 ${config.naps.topology.provisionerHost}:8081/${vmname}
                
            install -d -o root -g root -m 700 /tmp/assets
            tar -xvf /tmp/assets.tar.gz -C /tmp/assets && rm /tmp/assets.tar.gz
        '';

    processVM =
        vmname:
        vmassets: # type: AttrSet provider asset
        let allassets = utils.mergeAll (builtins.attrValues (builtins.removeAttrs vmassets ["plain"])); # we remove the plain assets (which are transmitted through the store)
        in utils.mergeAll [
                (mkFetchAll vmname (builtins.attrValues allassets))
                (mkCheckService vmname (builtins.attrValues allassets))
            ];

    mkCondition = allassets:
        lib.concatMapStringsSep "&&"
            ({installArgs, ...}:
                let path = installArgs.path;
                in ''-e "${path}"'')
            allassets;
    mkFetchAll =
        vmname:
        allassets:
        let

        in {
             ${vmname}.config.systemd.services."assets-fetch-all" = {
                    description = "Fetch the assets of the server";
                    serviceConfig = {
                        Type = "oneshot";
                        Restart = "on-failure";
                        RestartSec = "30s";
                    };
                    script = ''
                        until [[ ${mkCondition allassets} ]]; do
                            if
                            ${fetchAssetsScript vmname}
                            then
                                ${config.naps.assets.scripts.install.${vmname}}
                            else
                                sleep 2
                            fi
                        done
                        echo "All assets are installed."
                    '';
                };

        };


        mkCheckService = 
            vmname:
            allassets:
            let
                splitAssets =
                    lib.concatMap  
                        (asset@{reload, installArgs, ...}: 
                            map (srvname: {${srvname} =  [installArgs.path];}  ) reload) #plain assets are not download: they are installed directly in the store
                        allassets;
                assetsPerService = utils.mergeAll splitAssets; # {servicename = [path]}

                processService =
                    srvname:
                    assetslist:
                    let sortedassets = builtins.sort builtins.lessThan assetslist;
                        hashPath = "${srvname}.hash";
                        condition = lib.concatMapStringsSep " && "
                                        (path: 
                                            ''
                                                -e ${path}
                                            '')
                                        sortedassets;
                    in lib.optionalAttrs (assetslist != []) {
                        ${vmname}.config.systemd.services."assets-check-${srvname}" = {
                            description = "Checks if the assets of ${srvname} have changed";
                            serviceConfig = {
                                Type = "oneshot";
                                Restart = "on-failure";
                                RestartSec = "30s";
                            };
                            wants = ["assets-fetch-all.service"]; #starts assets-fetch-all in parallel. Useful to have a single fetch-all per VM, but a check per service
                            requiredBy = [srvname];

                            wantedBy = ["sysinit-reactivation.target" "multi-user.target"];
                            before = [srvname "sysinit-reactivation.target"]; #restart at every rebuild
                            script = ''
                                  if ! [[ ${mkCondition allassets} ]] then
                                      echo "Waiting for assets being downloaded."
                                      until ([[ ${condition} ]]); do
                                        sleep 2
                                      done
                                  fi
                                  NEW_HASH=$(for f in ${lib.concatStringsSep " " sortedassets}; do
                                                if [[ -f "$f" ]]; then
                                                    printf '%s\0' "$f"
                                                    cat "$f"
                                                elif [[ -d "$f" ]]; then
                                                    find "$f" -type f -print0 | sort -z | xargs -0 cat
                                                fi
                                             done | sha256sum | cut -d' ' -f1 ) 
                                  OLD_HASH=""
                                  if [[ -e "${hashPath}" ]]; then
                                    OLD_HASH=$(<"${hashPath}")
                                  fi
                                  
                                  if [[ "$OLD_HASH" != "$NEW_HASH" ]]; then
                                    echo "Assets have changed. Restarting ${srvname}."
                                    systemctl restart ${srvname}

                                    echo "$NEW_HASH" > ${hashPath}
                                  fi
                            '';
                        };
                    };

            in utils.mergeAll (lib.mapAttrsToList processService assetsPerService);



in {

    naps.outputs.systems = utils.mergeAll (lib.mapAttrsToList processVM (config.naps.assets.installer));
}


