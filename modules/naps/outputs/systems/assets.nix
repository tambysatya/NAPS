{flakeRoot, lib, inputs, config, pkgs, ...}:

/* Implements in-place assets updates */

let
    utils = import ../lib {inherit lib inputs flakeRoot;};

    fetchAssetsScript = 
        vmname:
        let 
            domain = config.naps.topology.domain;
            crt_basename= "vm-${vmname}.${domain}";
            installScript = pkgs.writeShellScript "fetch-all-assets" config.naps.assets.scripts.install.${vmname};
        in ''
            ${lib.getExe pkgs.curl} --cert ${utils.ssl_crt_path crt_basename} \
                 --key  ${utils.ssl_key_path crt_basename} \
                 --cacert /etc/root_ca.crt \
                 --output /tmp/assets.tar.gz \
                 https://${config.naps.topology.provisioner.hostname}:38422/mtls \
                
            install -d -o root -g root -m 700 /tmp/assets
            ${pkgs.gzip}/bin/gunzip /tmp/assets.tar.gz
            ${lib.getExe pkgs.gnutar} -xvf /tmp/assets.tar -C /tmp/assets && rm /tmp/assets.tar.gz

            ${installScript} /tmp/assets 
            rm -R /tmp/assets 
        '';
    checkAssetsScript = 
        srvname:
        env:
        assets: # map of assets (without the plain assets) 
        let 
            hashPath = "/var/lib/secrets/${srvname}.hash";
            reload = lib.concatLists (lib.mapAttrsToList (_: builtins.getAttr "reload") assets);
            paths = map (lib.getAttrFromPath ["installArgs" "path"]) (builtins.attrValues assets);
            sortedpaths = builtins.sort builtins.lessThan paths;
        in ''
              set -euo pipefail
              if ! [[ ${mkCondition (builtins.attrValues assets)} ]]; then
                  echo "Waiting for assets being downloaded."
                  until ([[ ${mkCondition (builtins.attrValues assets)} ]]); do
                    sleep 2
                  done
              fi
              NEW_HASH=$(for f in ${lib.concatStringsSep " " sortedpaths}; do
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
                ${ if env.type == "container"
                   then "${lib.getExe pkgs.nixos-container} run ${utils.envUID env} -- systemctl restart ${lib.concatStringsSep " " reload}"
                   else "systemctl restart ${lib.concatStringsSep " " reload}"
                }

                echo "$NEW_HASH" > ${hashPath}
              fi
        '';

    processVM =
        vmname:
        vmassets: # type: AttrSet provider asset
        let allassets = utils.mergeAll (builtins.attrValues (builtins.removeAttrs vmassets ["plain"])); # we remove the plain assets (which are transmitted through the store)
        in mkFetchAll vmname (builtins.attrValues allassets);

    mkCondition = allassets:
        lib.concatMapStringsSep "&&"
            ({installArgs, ...}:
                let path = installArgs.path;
                in '' -e "${path}" '')
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

                    /* Always wait for a new version of the assets */
                    script = ''

                        set -x
                        set -euo pipefail
                        until ${fetchAssetsScript vmname} do
                                sleep 2
                        done
                        echo "All assets are installed."
                    '';
                };

        };


        mkCheckService = 
            srvname: srvconf@{assets, endpoints, ...}:
            envname: env:
            let
                secrets = lib.filterAttrs (_: asset: asset.provider != "plain")  assets;
            in lib.optionalAttrs (secrets != {}) {
                        ${utils.envHost env}.config.systemd.services."assets-check-${srvname}" = {
                            description = "Checks if the assets of ${srvname} have changed";
                            serviceConfig = {
                                Type = "oneshot";
                                Restart = "on-failure";
                                RestartSec = "30s";
                            };
                            wants = ["assets-fetch-all.service"]; #starts assets-fetch-all in parallel. Useful to have a single fetch-all per VM, but a check per service

                            after = lib.optionals (env.type == "container") ["container@${envname}.service"];
                            requires = lib.optionals (env.type == "container") ["container@${envname}.service"];

                            wantedBy = ["nixos-rebuild-switch-to-configuration.service"]; # we let the service start: it will be restarted whenever the secrets are reached 
                            before = ["nixos-rebuild-switch-to-configuration.service"]; #restart at every rebuild
                            script = checkAssetsScript srvname env secrets;
                        };
              };

        processService = 
            srvname: srvconf@{deployements,...}:
            utils.mergeAll 
                (lib.mapAttrsToList (mkCheckService srvname srvconf) deployements);





in {

    naps.outputs.systems = utils.mergeAll (lib.mapAttrsToList processVM (config.naps.assets.installer) ++ lib.mapAttrsToList processService config.naps.services);
}


