{flakeRoot, lib, inputs, config, pkgs, ...}:

/* Implements in-place assets updates */

let
    utils = import ../lib {inherit lib inputs flakeRoot;};

    fetchAssetsScript = 
        vmname:
        let crt_basename= "vm-${vmname}";
        in ''
            ${lib.getExe pkgs.curl} --cert ${utils.ssl_crt_path crt_basename} \
                 --key  ${utils.ssl_key_path crt_basename} \
                 --cacert /etc/nixos/root_ca.crt \
                 --output /root/assets.tar.gz \
                 ${config.naps.topology.provisionerHost}:8081/mtls \
                 > /tmp/assets.tar.gz
                
            install -d -o root -g root -m 700 /tmp/assets
            tar -xvf /tmp/assets.tar.gz -C /tmp/assets && rm /tmp/assets.tar.gz

            ${config.naps.assets.scripts.install.${vmname}} /tmp/assets
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
                in '' -e "${path} "'')
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

                    /* While true because we always check if there is a neww version of the assets */
                    script = ''

                        set -euo pipefail
                        while true; do
                            if
                               !  ${fetchAssetsScript vmname}
                            then
                                sleep 2
                            fi

                            if [[ ${mkCondition allassets} ]]; then
                                break
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
                servicesInContainers = map (srvuid: config.naps.topology.services.${srvuid}.is) config.naps.topology.vms.${vmname}.containers;

                processService =
                    srvname:
                    assetslist:
                    let sortedassets = builtins.sort builtins.lessThan assetslist;
                        hashPath = "/var/lib/secrets/${srvname}.hash";
                        condition = lib.concatMapStringsSep " && "
                                        (path: 
                                            ''
                                                -e ${path}
                                            '')
                                        sortedassets;
                        srvuid = lib.filter (uid: config.naps.topology.services.${uid}.is == srvname) (config.naps.topology.vms.${vmname}.containers ++ config.naps.topology.vms.${vmname}.services);
                    in lib.optionalAttrs (assetslist != []) {
                        ${vmname}.config.systemd.services."assets-check-${srvname}" = {
                            description = "Checks if the assets of ${srvname} have changed";
                            serviceConfig = {
                                Type = "oneshot";
                                Restart = "on-failure";
                                RestartSec = "30s";
                            };
                            wants = ["assets-fetch-all.service"]; #starts assets-fetch-all in parallel. Useful to have a single fetch-all per VM, but a check per service

                            wantedBy = ["nixos-rebuild-switch-to-configuration.service"]; # we let the service start: it will be restarted whenever the secrets are reached 
                            before = ["nixos-rebuild-switch-to-configuration.service"]; #restart at every rebuild
                            script = ''
                                  set -euo pipefail
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
                                    ${ if builtins.elem srvname servicesInContainers
                                       then "${lib.getExe pkgs.nixos-containers} run ${srvuid} -- systemctl restart ${srvname}"
                                       else "systemctl restart ${srvname}"
                                    }

                                    echo "$NEW_HASH" > ${hashPath}
                                  fi
                            '';
                        };
                    };

            in utils.mergeAll (lib.mapAttrsToList processService assetsPerService);



in {

    naps.outputs.systems = utils.mergeAll (lib.mapAttrsToList processVM (config.naps.assets.installer));
}


