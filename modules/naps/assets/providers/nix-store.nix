{flakeRoot, lib, inputs, pkgs, path, config, ...}:
let

    utils = import ./lib {inherit flakeRoot lib inputs path pkgs;};
    types = import "${flakeRoot}/lib/types" {inherit lib inputs;};
    paths = utils.paths;
    domain = config.naps.topology.domain;
    generateNixStore = 
        assetname:
        keyname:
        let tgt = "${paths.out}/${assetname}";
        in ''
            if ! [[ -f ${tgt}/${utils.store_base_name keyname}.key ]]; then 
                mkdir -p ${tgt}
                nix-store --generate-binary-cache-key cache.${domain} ${tgt}/${utils.store_base_name keyname}.key ${tgt}/${utils.store_base_name keyname}.pub
            else
                 nix key convert-secret-to-public < ${tgt}/${utils.store_base_name keyname}.key > ${tgt}/${utils.store_base_name keyname}.pub
            fi
            cp ${tgt}/${utils.store_base_name keyname}.pub ${paths.git}
        '';

    generateSSH = 
       assetname:
       keyname:
       let tgt = "${paths.out}/${assetname}";
       in ''
            mkdir -p ${tgt}
            if ! [[ -f ${tgt}/${utils.ssh_base_name keyname} ]]; then
                ssh-keygen -t ed25519 -f ${tgt}/${utils.ssh_base_name keyname} -C "${keyname}@${domain}" -N "" -q
            fi
        '';

    installNixStore = 
        keyname:
        installArgs:
        ''
           ${utils.install (utils.store_base_name keyname) "file" installArgs}
        '';

    installSSH = 
        keyname:
        installArgs@{path, owner, group ? null, mode,  ...}:
        let tgt = "/mnt${path}";
            group' = if group == null then owner else group;
        in ''
            install -d -m 700 -o ${owner} -g ${owner} ${tgt}
            cp "$1/${utils.ssh_base_name keyname}/${utils.ssh_base_name keyname}" ${tgt}/id_ed25519
            cp "$1/${utils.ssh_base_name keyname}/${utils.ssh_base_name keyname}.pub" ${tgt}/id_ed25519.pub
            chown -R ${owner}:${group'} ${tgt}
            chmod ${mode} ${tgt}/*
        '';


in {

naps.assets.providers.ssh-keygen = {
    inputs = {
        installArgs = types.submodule {
            options = {
                inherit (types) owner;
                path = lib.mkOption {
                    description = "Where to install the ssh key";
                    type = types.str;
                    example = "/var/lib/hydra/.ssh";
                };
                mode = types.filemode;
            };
        };
    };
    apply = {
        generate = acc: assetname: args: acc ++ [(generateSSH assetname args.keyname)];
        install = assetname: args: installSSH args.generateArgs.keyname args.installArgs;
    };
};
naps.assets.providers.nix-store = {
    inputs = {
        installArgs = types.submodule {
            options = {
                inherit (types) owner;
                mode = types.filemode;
            };
        };
    };

    apply = {
        generate = acc: assetname: args: acc ++ [(generateNixStore assetname args.keyname)];
        install = assetname: args: installNixStore args.generateArgs.keyname args.installArgs;
    };
};
}


