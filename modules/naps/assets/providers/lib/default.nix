{flakeRoot, lib, inputs, path, ...}:

let
    utils = import "${flakeRoot}/lib" {inherit lib inputs;};

    paths = {
        git = "${path}/.secrets/git";
        out = "${path}/.secrets/out";
        perVM = "${path}/.secrets/perVM";
    };

    give = filename: envs: 
        let filepath = "${paths.out}/${filename}";
            target = env: "${paths.perVM}/${utils.envHost env}/${filename}";
        in lib.concatMapStringsSep "\n" (env: ''cp ${filepath} ${target env}'') envs;

    install = 
        filename: 
        {tgt ? "/var/lib/secrets", owner, group, mode,...}:
        ''
           cp "$1/${filename}" ${tgt}
           chown ${owner} ${tgt}
           chgrp ${group} ${tgt}
           chmod ${mode} ${tgt}
        '';




in lib // utils // {
    inherit paths give;
    inherit install;
}
