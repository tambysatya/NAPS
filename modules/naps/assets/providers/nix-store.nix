{flakeRoot, lib, inputs, pkgs, path, config, ...}:
let

    utils = import ./lib {inherit flakeRoot lib inputs path pkgs;};
    types = import "${flakeRoot}/lib" {inherit lib inputs;};
    paths = utils.paths;
    domain = config.naps.topology.domain;
    generateNixStore = 
        keyname:
        ''
            if ! [[ -f ${paths.out}/${utils.store_base_name keyname}.key ]]; then 
                nix-store --generate-binary-cache-key cache.${domain} ${paths.out}/${utils.store_base_name keyname}.key ${paths.out}/${utils.store_base_name keyname}.pub
            else
                 nix key convert-secret-to-public < ${paths.out}/${utils.store_base_name keyname}.key > ${paths.out}/${utils.store_base_name keyname}.pub
            fi
            cp ${paths.out}/${utils.store_base_name keyname}.pub" ${paths.git}
        '';

    generateSSH = 
       keyname:
        ''
            if ! [[ -f ${paths.out}/${utils.ssh_base_name keyname} ]]; then
                ssh-keygen -t ed25519 -f ${paths.out}/${utils.ssh_base_name keyname} -C "${keyname}@${domain}" -N "" -q
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
        installArgs@{path, owner, ...}:
        ''
            install -d -m 700 -o ${owner} -g ${owner} ${path}/.ssh
            cp "$1/${utils.ssh_base_name keyname}" ${path}/.ssh/id_ed25519
            cp "$1/${utils.ssh_base_name keyname}.pub" ${path}/.ssh/id_ed25519.pub
            chown -R ${owner}:${owner} ${path}§/ssh
        '';


in {

naps.assets.providers.ssh-keygen = {
    generate = acc: assetname: args: acc ++ [(generateSSH args.keyname)];
    install = assetname: args: installSSH args.generateArgs.keyname args.installArgs;
};
naps.assets.providers.nix-store = {
    generate = acc: assetname: args: acc ++ [(generateNixStore args.keyname)];
    install = assetname: args: installNixStore args.generateArgs.keyname args.installArgs;
};
}


