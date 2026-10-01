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
        let allassets = utils.mergeAll (builtins.attrValues vmassets);
        in utils.mergeAll [
                (mkFetchAllAssets vmname (builtins.attrValues allassets))
                (utils.mergeAll 
                    (lib.mapAttrsToList (mkAssetExistsService vmname) allassets))
            ];

    mkAssetExistsService = 
        vmname:
        assetname:
        {installArgs, reload, ...}:
        let path = installArgs.path;
        in {
               ${vmname}.config.systemd.services."asset-${assetname}-exists" = {
                    description = "Waits until ${assetname} is present in ${path}";
                    serviceConfig = {
                        Type = "oneshot";
                        Restart = "on-failure";
                        RestartSec = "30s";
                    };
                    before = reload;
                    requiredBy = reload;
                    wants = ["fetch-all-assets.service"]; #TODO add after ?
                    script = ''
                        until [[ -e "${path}" || -L "${path}" ]]; do
                            sleep 2
                        done
                    '';
                };

        };

    mkFetchAllAssets = 
        vmname:
        allassets:
        let 
           condition =
                lib.concatMapStringsSep "&&"
                    ({installArgs, ...}:
                        let path = installArgs.path;
                        in ''-e "${path}"'')
                    allassets;
        in {
             ${vmname}.config.systemd.services."fetch-all-assets" = {
                    description = "Fetch the assets of the server";
                    serviceConfig = {
                        Type = "oneshot";
                        Restart = "on-failure";
                        RestartSec = "30s";
                    };
                    script = ''
                        until [[ ${condition} ]]; do
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

in {

    naps.outputs.systems = utils.mergeAll (lib.mapAttrsToList processVM (config.naps.assets.installer));
}


